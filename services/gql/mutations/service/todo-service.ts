import TodoDao from '../dao/todo-dao'
import { CreateTodoListRequest, MutationInputFieldError } from '../../../../generated/api'

export default class TodoService {
  public async validateTodoList(
    createToDoList: CreateTodoListRequest
  ): Promise<{ hasError: boolean; fieldErrors: MutationInputFieldError[] }> {
    if (createToDoList.listName === 'test') {
      return {
        hasError: true,
        fieldErrors: [
          {
            path: 'listName',
            message: 'Value test not allowed',
          },
        ],
      }
    }

    return {
      hasError: false,
      fieldErrors: [],
    }
  }

  public async createTodoList(pgClient: any, createToDoList: CreateTodoListRequest) {
    const todoDao = new TodoDao()
    return await todoDao.persistTodoList(pgClient, createToDoList)
  }
}
