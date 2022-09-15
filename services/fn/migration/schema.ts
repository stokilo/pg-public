import { APIGatewayProxyEvent, APIGatewayProxyHandler } from 'aws-lambda'
import pgApp from '../../pg-app'

export const lambdaFn: APIGatewayProxyHandler = async (event: APIGatewayProxyEvent) => {
  await pgApp.createGraphqlSchema()

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: '{}',
  }
}
