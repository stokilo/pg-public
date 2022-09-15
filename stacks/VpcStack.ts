import { StackContext } from '@serverless-stack/resources'
import * as ec2 from 'aws-cdk-lib/aws-ec2'

export function VpcStack({ stack }: StackContext) {
  const vpc = new ec2.Vpc(stack, 'vpc', {
    cidr: '10.16.0.0/16',
    natGateways: 0,
    maxAzs: 3,
    enableDnsHostnames: true,
    enableDnsSupport: true,
    subnetConfiguration: [
      {
        cidrMask: 24,
        name: 'public-subnet',
        subnetType: ec2.SubnetType.PUBLIC,
      },
      {
        cidrMask: 24,
        name: 'private-subnet',
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
    ],
  })

  const securityGroup = new ec2.SecurityGroup(stack, 'security-group', {
    vpc,
    securityGroupName: 'security-group-isolated',
    allowAllOutbound: true,
  })

  return {
    vpc,
    securityGroup,
  }
}
