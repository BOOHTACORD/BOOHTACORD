import { context, SpanKind, SpanStatusCode, type Tracer } from '@opentelemetry/api'
import { apiBaseUrl } from '../config/runtime'
import { telemetrySession } from './action_scope/session'

export function routinePresenceRequest(input:RequestInfo|URL,method:string):boolean {
 const base=typeof window==='undefined'?'https://example.test':window.location.origin
 const path=new URL(input instanceof Request?input.url:String(input),base).pathname.slice(apiBaseUrl.length)
 return (method==='GET'||method==='PUT')&&/^\/voice\/leases\/[^/]+\/screen-viewers(?:\/[^/]+)?$/.test(path)
}

// Successful unscoped presence calls have server-side count/latency metrics.
// Create a diagnostic span only on failure; never record a lease, URL or error text.
export async function traceRoutineRequest(tracer:Tracer,call:()=>Promise<Response>,method:string):Promise<Response> {
 const parent=context.active(),startTime=Date.now(),owner=telemetrySession.snapshot()
 const failed=(status?:number)=>{
  if(!telemetrySession.current(owner))return
  const span=tracer.startSpan('api.request',{kind:SpanKind.CLIENT,startTime},parent)
  span.setAttribute('http.request.method',method)
  if(status!==undefined)span.setAttribute('http.response.status_code',status)
  span.setStatus({code:SpanStatusCode.ERROR});span.end()
 }
 try {
  const response=await call()
  if(response.status>=400)failed(response.status)
  return response
 }catch(error){failed();throw error}
}
