import type { Outcome } from './scope'
export function failureOutcome(error:unknown):{outcome:Outcome;reason:string} {
 const status=typeof error==='object'&&error!==null&&'status' in error?error.status:undefined
 if(status===401||status===403)return {outcome:'rejected',reason:'permission_denied'}
 if(status===409)return {outcome:'rejected',reason:'conflict'}
 if(typeof status==='number'&&status>=400&&status<500)return {outcome:'rejected',reason:'invalid'}
 if(error instanceof DOMException){
  if(error.name==='TimeoutError')return {outcome:'timeout',reason:'deadline'}
  if(error.name==='AbortError')return {outcome:'cancelled',reason:'disposed'}
  if(error.name==='NotAllowedError'||error.name==='SecurityError')return {outcome:'rejected',reason:'permission_denied'}
  if(error.name==='NotSupportedError')return {outcome:'rejected',reason:'unsupported'}
 }
 return {outcome:'failed',reason:typeof status==='number'?'dependency':'network'}
}
