import { App } from '@serverless-stack/resources'
import { VpcStack } from './VpcStack'
import { RdsStack } from './RdsStack'
import { GqlApi } from './GqlApi'
import { Functions } from './Functions'
import { S3Migration } from './S3Migration'

export default function main(app: App) {
  app.setDefaultFunctionProps({
    runtime: 'nodejs16.x',
    srcPath: 'services',
    bundle: {
      format: 'esm',
    },
  })
  app.stack(VpcStack).stack(RdsStack).stack(GqlApi).stack(Functions).stack(S3Migration)
}
