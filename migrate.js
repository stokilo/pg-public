const shell = require('shelljs')

const exec2JSON = (command) => {
  const raw = shell.exec(command, { silent: true })
  return raw.code === 0 ? JSON.parse(raw) : {}
}

const migrate = () => {
  shell.echo('Sync migration/rds into s3...')
  shell.exec(`aws s3 sync \
             ./stacks/migration/db s3://org.stec.project.pg.dev.migration.db.bucket \
             --delete --no-progress `)

  shell.echo('Migrate...')
  const functions = exec2JSON(`aws lambda list-functions`)
  const dbMigrationFn = functions.Functions.find((e) => {
    return e.FunctionName.includes('DatabaseMigrationFunction')
  })

  const schemaMigrationFn = functions.Functions.find((e) => {
    return e.FunctionName.includes('SchemaMigrationFunction')
  })

  const invokeDb = exec2JSON(`aws lambda invoke \
                                     --function-name ${dbMigrationFn.FunctionName} \
                                     ./generated/migration.json
                                 `)
  console.dir(invokeDb.StatusCode === 200 ? 'Database migration OK': 'Database migration NOK')

  const invokeSchema = exec2JSON(`aws lambda invoke \
                                     --function-name ${schemaMigrationFn.FunctionName} \
                                     ./generated/migration.json
                                 `)
  console.dir(invokeSchema.StatusCode === 200 ? 'Schema migration OK': 'Schema migration NOK')

  shell.exec(`aws s3 cp s3://org.stec.project.pg.dev.migration.schema.bucket/schema.gql ./generated/schema.gql --quiet`)

  shell.exec('yarn codegen')
}

migrate()
