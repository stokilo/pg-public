import { GraphQLResolveInfo } from 'graphql'
import { GraphileHelpers } from 'graphile-utils/node8plus/fieldHelpers'
import type { SQL } from 'graphile-build-pg'

/**
 * This is postgraphile API function to convert SQL to to GraphQL AST object returned in the
 * mutation responses.
 */
export async function getRowByIdAsGraphQLResult(
  resolveInfo: GraphQLResolveInfo & {
    graphile: GraphileHelpers<any>
  },
  sql: any,
  tableFragment: SQL,
  person: { id: string }
) {
  const [row] = await resolveInfo.graphile.selectGraphQLResultFromTable(tableFragment, (tableAlias, queryBuilder) => {
    queryBuilder.where(sql.fragment`${tableAlias}.id = ${sql.value(person.id)}`)
  })

  return row
}
