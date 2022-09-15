import { MutationInputFieldError } from '../../../generated/api'
import { SafeParseError } from 'zod/lib/types'

export const createFieldErrorResponse = <T>(
  parseError: SafeParseError<T>
): { hasError: boolean; fieldErrors: MutationInputFieldError[] } => {
  const errors: MutationInputFieldError[] = []
  parseError.error.errors.map((e) => {
    errors.push({
      path: e.path[0] as string,
      message: e.message,
    })
  })

  return {
    hasError: true,
    fieldErrors: errors,
  }
}
