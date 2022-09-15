import * as z from 'zod'

export const ZOD_ERROR_MAP_PL: z.ZodErrorMap = (error, ctx) => {
  switch (error.code) {
    case z.ZodIssueCode.too_small:
      return { message: `Za krotki ten string chlopie !` }
  }

  return { message: ctx.defaultError }
}
