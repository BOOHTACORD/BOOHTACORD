import {writeFileSync} from 'node:fs'
import {join} from 'node:path'

export function writeFailure(directory,stage,error) {
  const stages=new Set(['startup','guest','login','voice','faults','cancellation'])
  const types=new Set(['Error','TypeError','SyntaxError','AssertionError','TimeoutError','ExpectError'])
  const value={status:'FAIL',stage:stages.has(stage)?stage:'startup',
    errorType:types.has(error?.constructor?.name)?error.constructor.name:'Error'}
  writeFileSync(join(directory,'failure.json'),JSON.stringify(value)+'\n')
  return value
}
