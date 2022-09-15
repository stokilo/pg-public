import { StackContext } from '@serverless-stack/resources'
import { Function } from '@serverless-stack/resources'
import * as iam from 'aws-cdk-lib/aws-iam'

export function Functions({ stack }: StackContext) {
  const dbMigrationFn = new Function(stack, 'DatabaseMigrationFunction', {
    handler: 'fn/migration/db.lambdaFn',
    timeout: 15,
    bundle: {
      nodeModules: ['pg', 'sqlite3', 'oracledb', 'mysql', 'tedious', 'better-sqlite3', 'pg-query-stream', 'mysql2'],
      sourcemap: true,
    },
    environment: {
      NODE_OPTIONS: '--enable-source-maps',
      PARAMETER_STORE_PREFIX: `/sst/pg/${stack.stage}/parameters`,
    },
  })

  const schemaMigrationFn = new Function(stack, 'SchemaMigrationFunction', {
    handler: 'fn/migration/schema.lambdaFn',
    timeout: 15,
    bundle: {
      nodeModules: ['pg', 'sqlite3', 'oracledb', 'mysql', 'tedious', 'better-sqlite3', 'pg-query-stream', 'mysql2'],
      sourcemap: true,
    },
    environment: {
      NODE_OPTIONS: '--enable-source-maps',
      PARAMETER_STORE_PREFIX: `/sst/pg/${stack.stage}/parameters`,
    },
  })

  dbMigrationFn.attachPermissions([
    new iam.PolicyStatement({
      actions: ['ssm:GetParameter', 'secretsmanager:GetSecretValue', 'secretsmanager:PutSecretValue', 's3:*'],
      effect: iam.Effect.ALLOW,
      resources: ['*'],
    }),
  ])

  schemaMigrationFn.attachPermissions([
    new iam.PolicyStatement({
      actions: ['ssm:GetParameter', 'secretsmanager:GetSecretValue', 's3:*'],
      effect: iam.Effect.ALLOW,
      resources: ['*'],
    }),
  ])
}
