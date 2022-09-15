import * as z from 'zod'
import { ZOD_ERROR_MAP_PL } from './zod-pl'
import { ZOD_ERROR_MAP_EN } from './zod-en'

export const setZodErrorMapForRequest = (acceptLanguageHeader: string) => {
  if (acceptLanguageHeader === 'pl') {
    z.setErrorMap(ZOD_ERROR_MAP_PL)
  } else {
    z.setErrorMap(ZOD_ERROR_MAP_EN)
  }
}
