import { Api, Config, StackContext } from '@serverless-stack/resources'
import * as iam from 'aws-cdk-lib/aws-iam'

export function GqlApi({ stack }: StackContext) {
  const api: Api = new Api(stack, 'Api', {
    defaults: {
      function: {
        bundle: {
          nodeModules: ['pg', 'sqlite3', 'oracledb', 'mysql', 'tedious', 'better-sqlite3', 'pg-query-stream', 'mysql2'],
          sourcemap: true,
        },
        environment: {
          NODE_OPTIONS: '--enable-source-maps',
          PARAMETER_STORE_PREFIX: `/sst/pg/${stack.stage}/parameters`,
        },
      },
    },
    cors: {
      allowHeaders: ['*'],
      allowMethods: ['POST'],
      allowOrigins: ['http://127.0.0.1:5173'],
    },
    routes: {
      'POST /query': 'fn/query.lambdaFn',
    },
  })

  api.attachPermissions([
    new iam.PolicyStatement({
      actions: ['ssm:GetParameter', 'secretsmanager:GetSecretValue', 's3:*'],
      effect: iam.Effect.ALLOW,
      resources: ['*'],
    }),
  ])

  new Config.Parameter(stack, 'API_URL', {
    value: api.url,
  })

  stack.addOutputs({
    API_URL_OUTPUT: api.url,
  })

  return api
}
