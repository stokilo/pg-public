import { gql, makeExtendSchemaPlugin } from 'postgraphile'

export const TypeDefPlugin = makeExtendSchemaPlugin((build) => {
  const { pgSql: sql } = build
  return {
    typeDefs: gql`
      type MutationInputFieldError {
        path: String!
        message: String!
      }
    `,
    resolvers: {},
  }
})
