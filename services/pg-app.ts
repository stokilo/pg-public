import { GetSecretValueCommand, PutSecretValueCommand, SecretsManagerClient } from '@aws-sdk/client-secrets-manager'
import { Pool } from 'pg'
import { PostGraphileOptions } from 'postgraphile/build/interfaces'
import { createPostGraphileSchema, withPostGraphileContext } from 'postgraphile'
import { graphql, GraphQLSchema, printSchema } from 'graphql'
import { readBinaryBucket, readTextBucket } from './s3/s3-reader'
import { TodoMutationPlugin } from './gql/mutations/todo-mutation'
import { saveBinaryObject, saveTextObject } from './s3/s3-writer'
const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm')
import fs from 'fs'
import { TypeDefPlugin } from './gql/mutations/type-def'

type RdsSecret = {
  host: string
  port: number
  username: string
  password: string
  dbname: string
  'dbuser-username': string
  'dbuser-password': string
}

class PgApp {
  public static readonly GRAPHQL_TARGET_SCHEMA = ['app_public']
  private static readonly LAMBDA_TMP_FOLDER = '/tmp/cache'

  private static readonly SECRET_KEY_DB_USER_USERNAME = 'dbuser-username'
  private static readonly DB_USER_USERNAME = 'dbuser'
  private static readonly SECRET_KEY_DB_USER_PASSWORD = 'dbuser-password'

  private isInitialized = false
  private ssmClient: typeof SSMClient
  private secretClient: SecretsManagerClient | undefined

  private rdsSecretArn: string = ''
  private s3SchemaMigrationFolder: string = ''
  private s3DbMigrationFolder: string = ''
  private rdsSecret: RdsSecret | undefined

  private pgPool: Pool | undefined
  private postGraphileOptions: PostGraphileOptions | undefined

  private graphqlSchema: GraphQLSchema | undefined

  constructor() {}

  public async init(useCache = false, isDbUser = false, sqlMigration = false) {
    if (!this.isInitialized) {
      console.log('Pg runtime is not initialized, initialize pg and postgraphile')

      try {
        this.ssmClient = new SSMClient({ region: process.env.AWS_REGION })
        this.secretClient = new SecretsManagerClient({
          region: process.env.AWS_REGION,
        })

        this.rdsSecretArn = await this.getParam('RDS_SECRET_ARN')
        this.s3SchemaMigrationFolder = await this.getParam('SCHEMA_MIGRATION_FOLDER_S3_BUCKET_NAME')
        this.s3DbMigrationFolder = await this.getParam('DB_MIGRATION_FOLDER_S3_BUCKET_NAME')
        this.rdsSecret = JSON.parse(await this.getSecret(this.rdsSecretArn))

        this.pgPool = new Pool({
          host: this.rdsSecret!.host,
          port: this.rdsSecret!.port,
          user: isDbUser ? this.rdsSecret!['dbuser-username'] : this.rdsSecret!.username,
          password: isDbUser ? this.rdsSecret!['dbuser-password'] : this.rdsSecret!.password,
          database: this.rdsSecret!.dbname,
          max: 1,
        })

        if (!sqlMigration) {
          this.postGraphileOptions = {
            dynamicJson: true,
            graphiql: false,
            appendPlugins: [TodoMutationPlugin, TypeDefPlugin],
          }
          if (useCache) {
            const cache = await readBinaryBucket(this.s3SchemaMigrationFolder, 'schema.cache')
            this.postGraphileOptions['readCache'] = JSON.parse(new TextDecoder().decode(cache))
          }

          this.graphqlSchema = await createPostGraphileSchema(this.pgPool, PgApp.GRAPHQL_TARGET_SCHEMA, {
            ...this.postGraphileOptions,
          })
        }

        this.isInitialized = true
        console.log('Pg runtime is initialized.')
      } catch (e) {
        console.dir(e)
      }
    }
  }

  public async query(userId: string, graphqlQuery: string, variables = {}) {
    await this.init(true, false)
    this.postGraphileOptions!.pgSettings = {
      'user.id': userId,
    }
    return await withPostGraphileContext(
      {
        ...this.postGraphileOptions,
        pgPool: this.pgPool!,
        pgSettings: this.postGraphileOptions!.pgSettings,
      },
      async (context: any) => {
        return await graphql(
          this.graphqlSchema!,
          graphqlQuery,
          null,
          {
            ...context,
          },
          variables,
          null
        )
      }
    )
  }

  public async migrate() {
    await this.init(false, false, true)
    console.log('Migrate SQL database.')
    // fetch existing password or use generated one
    const dbUserPassword = await this.dbUserSecretSetup(this.rdsSecretArn)

    const initSql = await readTextBucket(this.s3DbMigrationFolder, 'init.sql')
    const toRun = `
       DO 
       $$
       BEGIN
           IF (SELECT NOT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_public')) THEN
              DROP ROLE IF EXISTS ${PgApp.DB_USER_USERNAME};
              CREATE ROLE ${PgApp.DB_USER_USERNAME} CREATEDB LOGIN PASSWORD '${dbUserPassword}';
           END IF;
       END
       $$;
       
       ${initSql}
       
       GRANT USAGE ON SCHEMA "app_public" TO ${PgApp.DB_USER_USERNAME};
       GRANT USAGE ON SCHEMA "app_private" TO ${PgApp.DB_USER_USERNAME};
       
       GRANT ALL ON ALL TABLES IN SCHEMA "app_public" TO ${PgApp.DB_USER_USERNAME};
       GRANT ALL ON ALL TABLES IN SCHEMA "app_private" TO ${PgApp.DB_USER_USERNAME};
       
       GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA "app_public" TO ${PgApp.DB_USER_USERNAME};
       GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA "app_private" TO ${PgApp.DB_USER_USERNAME};
    `
    await this.pgPool!.query(toRun)
    console.log('SQL migration done.')

    console.log('dvd-schema')
    await this.pgPool!.query(await readTextBucket(this.s3DbMigrationFolder, 'dvd-schema.sql'))
    console.log('dvd-data')
    await this.pgPool!.query(await readTextBucket(this.s3DbMigrationFolder, 'dvd-data.sql'))
    console.log('DVD migration done.')
  }

  public async createGraphqlSchema() {
    await this.init()
    console.log('Create graphql schema...')

    this.postGraphileOptions!['writeCache'] = PgApp.LAMBDA_TMP_FOLDER
    this.postGraphileOptions!['disableDefaultMutations'] = true

    const schema = await createPostGraphileSchema(this.pgPool!, PgApp.GRAPHQL_TARGET_SCHEMA, {
      ...this.postGraphileOptions,
    })
    console.log('Save GQL schema to S3...')
    await saveTextObject(this.s3SchemaMigrationFolder, 'schema.gql', printSchema(schema))

    console.log('Save postgraphile cache to S3...')
    const fileStream = fs.createReadStream(PgApp.LAMBDA_TMP_FOLDER)
    await saveBinaryObject(this.s3SchemaMigrationFolder, 'schema.cache', fileStream)
  }

  public async release() {
    await this.pgPool!.end()
  }

  async getParam(param: string) {
    return (
      await this.ssmClient.send(
        new GetParameterCommand({
          Name: `${process.env.PARAMETER_STORE_PREFIX}/${param}`,
          WithDecryption: false,
        })
      )
    ).Parameter.Value
  }

  async getSecret(secretId: string) {
    return (
      await this.secretClient!.send(
        new GetSecretValueCommand({
          SecretId: secretId,
        })
      )
    ).SecretString!
  }

  /**
   * Setup 'dbuser' secret username/password in AWS Secret Manager. It generates a random password for the user
   * if secret doesn't contain it.
   * @param secretId
   */
  async dbUserSecretSetup(secretId: string) {
    const secretAsJson = JSON.parse(
      (
        await this.secretClient!.send(
          new GetSecretValueCommand({
            SecretId: secretId,
          })
        )
      ).SecretString!
    )

    const randomPassword = Math.random().toString(36).slice(-10) + new Date().toISOString()
    if (!(PgApp.SECRET_KEY_DB_USER_USERNAME in secretAsJson)) {
      secretAsJson[PgApp.SECRET_KEY_DB_USER_PASSWORD] = randomPassword
      secretAsJson[PgApp.SECRET_KEY_DB_USER_USERNAME] = PgApp.DB_USER_USERNAME
      await this.secretClient!.send(
        new PutSecretValueCommand({ SecretId: secretId, SecretString: JSON.stringify(secretAsJson) })
      )
    } else {
      return secretAsJson[PgApp.SECRET_KEY_DB_USER_PASSWORD]
    }

    return randomPassword
  }
}

const pgApp = new PgApp()
export default pgApp
