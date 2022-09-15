import * as z from 'zod'

export const ZOD_ERROR_MAP_EN: z.ZodErrorMap = (error, ctx) => {
  switch (error.code) {
    case z.ZodIssueCode.too_small:
      return { message: `This is very very short string :)` }
  }

  return { message: ctx.defaultError }
}
