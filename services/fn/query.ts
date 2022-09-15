import { APIGatewayProxyEvent, APIGatewayProxyHandler } from 'aws-lambda'
import pgApp from '../pg-app'
import { setZodErrorMapForRequest } from '../common/i18n/zod-i18n'

export const lambdaFn: APIGatewayProxyHandler = async (event: APIGatewayProxyEvent) => {
  setZodErrorMapForRequest(event.headers['accept-language']!)
  const reqBody = JSON.parse(event.body!)

  console.log('Query:', reqBody.query)
  console.log('Variables:', reqBody.variables)

  const result = await pgApp.query(event.headers['authuserid']!, reqBody.query, reqBody.variables)
  console.log('Result:', result)

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(result, null, 2),
  }
}
