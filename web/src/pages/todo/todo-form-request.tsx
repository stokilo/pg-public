import * as React from 'react'
import { CreateToDoListMutation, CreateTodoListRequest, CreateTodoListResponse } from '../../../../generated/api'
import { gql, useMutation } from 'urql'
import TodoFormControl from './todo-form-control'

const CreateTodoList = gql`
  mutation CreateToDoList($input: CreateTodoListRequest!) {
    createTodo(input: $input) {
      hasError
      fieldErrors {
        path
        message
      }
      todoList {
        name
        id
      }
    }
  }
`

export function TodoFormRequest() {
  const [, createTodoList] = useMutation<CreateToDoListMutation>(CreateTodoList)

  const handleSubmit = async (data: CreateTodoListRequest): Promise<CreateTodoListResponse> => {
    console.log('handleSubmit', data)
    const callResult = await createTodoList({ input: { ...data } })

    if (callResult.error) {
      throw new Error(callResult.error.message)
    }

    return callResult.data?.createTodo as CreateTodoListResponse
  }

  return <TodoFormControl onSubmit={handleSubmit} />
}

export function TodoForm() {
  return <TodoFormRequest />
}
