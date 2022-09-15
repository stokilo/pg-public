import { Bucket, Config, StackContext } from '@serverless-stack/resources'
import { BlockPublicAccess } from 'aws-cdk-lib/aws-s3'
import { RemovalPolicy } from 'aws-cdk-lib'
import { BucketDeployment, Source, StorageClass } from 'aws-cdk-lib/aws-s3-deployment'

export function S3Migration({ stack }: StackContext) {
  const dbMigrationBucketName = `org.stec.project.pg.${stack.stage}.migration.db.bucket`
  const schemaMigrationBucketName = `org.stec.project.pg.${stack.stage}.migration.schema.bucket`

  const dbMigrationBucket = new Bucket(stack, 'DbMigrationBucket', {
    cdk: {
      bucket: {
        bucketName: dbMigrationBucketName,
        publicReadAccess: false,
        blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
        removalPolicy: RemovalPolicy.DESTROY,
        autoDeleteObjects: true,
      },
    },
  })

  const schemaMigrationBucket = new Bucket(stack, 'SchemaMigrationBucket', {
    cdk: {
      bucket: {
        bucketName: schemaMigrationBucketName,
        publicReadAccess: false,
        blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
        removalPolicy: RemovalPolicy.DESTROY,
        autoDeleteObjects: true,
      },
    },
  })

  new BucketDeployment(stack, 'DbMigrationDeployment', {
    sources: [Source.asset('./stacks/migration/db/')],
    destinationBucket: dbMigrationBucket.cdk.bucket,
    retainOnDelete: false,
    prune: true,
    storageClass: StorageClass.STANDARD,
    memoryLimit: 3008,
  })

  new Config.Parameter(stack, 'DB_MIGRATION_FOLDER_S3_BUCKET_NAME', {
    value: dbMigrationBucket.bucketName,
  })

  new Config.Parameter(stack, 'SCHEMA_MIGRATION_FOLDER_S3_BUCKET_NAME', {
    value: schemaMigrationBucket.bucketName,
  })
}
