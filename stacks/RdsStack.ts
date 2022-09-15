import { Config, StackContext, use } from '@serverless-stack/resources'
import * as ec2 from 'aws-cdk-lib/aws-ec2'
import * as rds from 'aws-cdk-lib/aws-rds'
import { RemovalPolicy } from 'aws-cdk-lib'
import { RetentionDays } from 'aws-cdk-lib/aws-logs'
import { VpcStack } from './VpcStack'

export function RdsStack({ stack }: StackContext) {
  const vpcStack = use(VpcStack)

  const dbInstance = new rds.DatabaseInstance(stack, 'rds-instance', {
    vpc: vpcStack.vpc,
    vpcSubnets: {
      //todo: unsafe, only for testing
      subnetType: ec2.SubnetType.PUBLIC,
    },
    databaseName: 'main',
    securityGroups: [vpcStack.securityGroup],
    engine: rds.DatabaseInstanceEngine.postgres({
      version: rds.PostgresEngineVersion.VER_13_4,
    }),
    instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
    removalPolicy: RemovalPolicy.DESTROY,
    deletionProtection: false,
    cloudwatchLogsRetention: RetentionDays.ONE_DAY,
    credentials: rds.Credentials.fromGeneratedSecret('postgres'),
  })

  //todo: for testing
  dbInstance.connections.allowFromAnyIpv4(ec2.Port.allTraffic(), 'Open to the world')

  return {
    rds: dbInstance,
    parameters: [
      new Config.Parameter(stack, 'RDS_SECRET_ARN', {
        value: dbInstance.secret!.secretArn,
      }),
      new Config.Parameter(stack, 'RDS_ENDPOINT_ADDRESS', {
        value: dbInstance.dbInstanceEndpointAddress,
      }),
    ],
  }
}
