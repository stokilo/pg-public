import { gql, makeExtendSchemaPlugin } from 'postgraphile'
import { getRowByIdAsGraphQLResult } from './sql2gql'
import { CreateTodoListRequest, MutationInputFieldError } from '../../../generated/api'
import TodoService from './service/todo-service'
import { createTodoListRequestSchema } from '../../common/schemas/todo-schema'
import { createFieldErrorResponse } from './errors'

export const TodoMutationPlugin = makeExtendSchemaPlugin((build) => {
  const { pgSql: sql } = build
  return {
    typeDefs: gql`
      input TodoItemRequest {
        body: String!
        headline: String!
      }

      input CreateTodoListRequest {
        listName: String!
        items: [TodoItemRequest]
      }

      type CreateTodoListResponse {
        hasError: Boolean!
        fieldErrors: [MutationInputFieldError]!
        todoList: TodoList @pgField
        query: Query
      }

      extend type Mutation {
        createTodo(input: CreateTodoListRequest!): CreateTodoListResponse
      }
    `,
    resolvers: {
      Mutation: {
        createTodo: async (_query, args, context, resolveInfo) => {
          const { pgClient } = context

          const parseResult = createTodoListRequestSchema.safeParse(args.input)
          if (parseResult.success) {
            const createToDoList: CreateTodoListRequest = parseResult.data
            const todoService = new TodoService()

            const validationResult = await todoService.validateTodoList(createToDoList)
            if (validationResult.hasError) {
              return validationResult
            } else {
              const todoList = await todoService.createTodoList(pgClient, createToDoList)

              return {
                data: await getRowByIdAsGraphQLResult(
                  resolveInfo,
                  sql,
                  sql.fragment`app_public.todo_list`,
                  todoList[0]
                ),
                query: build.$$isQuery,
                hasError: false,
                fieldErrors: [],
              }
            }
          } else {
            return createFieldErrorResponse<CreateTodoListRequest>(parseResult)
          }
        },
      },
    },
  }
})
