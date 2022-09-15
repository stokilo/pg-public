import { ZodType } from 'zod'
import { CreateTodoListRequest } from '../../../generated/api'
import * as z from 'zod'

export const createTodoListRequestSchema: ZodType<CreateTodoListRequest> = z.object({
  listName: z.string().min(3),
  items: z.array(z.object({ body: z.string().min(1), headline: z.string().min(1) })),
})
