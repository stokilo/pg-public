import * as React from 'react'
import { useForm } from 'react-hook-form'
import { CreateTodoListRequest, CreateTodoListResponse } from '../../../../generated/api'
import { zodResolver } from '@hookform/resolvers/zod'
import { createTodoListRequestSchema } from '@pg/services/common/schemas/todo-schema'
import TodoFormView from './todo-form-view'

type Props = {
  onSubmit: (data: CreateTodoListRequest) => Promise<CreateTodoListResponse | undefined>
}

export default function TodoFormControl({ onSubmit }: Props) {
  const form = useForm<CreateTodoListRequest>({
    mode: 'onSubmit',
    defaultValues: { listName: '' },
    resolver: zodResolver(createTodoListRequestSchema),
  })

  const handleSubmit = async (data: CreateTodoListRequest) => {
    console.log('submit')
    try {
      const result = await onSubmit(data)
      if (result) {
        if (result.hasError) {
          result.fieldErrors.forEach((e) => {
            // @ts-ignore
            form.setError(e!.path, {
              message: e!.message,
            })
          })
        }
      }
    } catch (e) {
      console.dir(e)
    }
  }

  return <TodoFormView form={form} onSubmit={handleSubmit} />
}
