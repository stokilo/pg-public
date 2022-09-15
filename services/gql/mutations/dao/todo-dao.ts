import knex from 'knex'
import { CreateTodoListRequest } from '../../../../generated/api'

export default class TodoDao {
  public async persistTodoList(pgClient: any, createToDoList: CreateTodoListRequest) {
    try {
      await pgClient.query('SAVEPOINT graphql_mutation')
      const todoList = await knex({ client: 'pg' })('app_public.todo_list')
        .connection(pgClient)
        .insert({ name: createToDoList.listName })
        .returning('*')

      if (createToDoList.items) {
        const todos = createToDoList.items.map((item) => {
          return { ...item, list_id: todoList[0].id }
        })
        await knex({ client: 'pg' })('app_public.todo_item').connection(pgClient).insert(todos).returning('*')
      }

      return todoList
    } catch (e) {
      await pgClient.query('ROLLBACK TO SAVEPOINT graphql_mutation')
      console.dir(e)
      throw e
    } finally {
      await pgClient.query('RELEASE SAVEPOINT graphql_mutation')
    }
  }
}
