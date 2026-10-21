import { context, SpanKind, SpanStatusCode, trace, type Span, type Tracer } from '@opentelemetry/api'
import { apiBaseUrl } from '../config/runtime'
import { ActionScope, activeAction } from './action_scope/scope'
import { telemetrySession } from './action_scope/session'
import { actionHeaders, acceptSessionResponse } from './action_scope/http_context'
import { failureOutcome } from './action_scope/failure'

export type OperationName = 'voice.join' | 'voice.leave' | 'voice.reconnect' | 'realtime.connect' | 'realtime.reconnect' | 'screen.share.start' | 'screen.share.stop' | 'screen.view'

function safeMethod(value: string): string {
  const method = value.toUpperCase()
  return ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'].includes(method) ? method : 'OTHER'
}

function shouldTrace(input: RequestInfo | URL): boolean {
  const base = typeof window === 'undefined' ? 'https://example.test' : window.location.origin
  const url = new URL(input instanceof Request ? input.url : String(input), base)
  if (url.origin !== base || !url.pathname.startsWith(`${apiBaseUrl}/`)) return false
  return !new Set(['/health', '/maintenance', '/maintenance/events', '/auth/session', '/telemetry/traces', '/voice/screen-metrics', '/voice/rosters/events']).has(url.pathname.slice(apiBaseUrl.length))
}

export function createTracedFetch(tracer: Tracer, transport: typeof fetch): typeof fetch {
  return async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    if (!shouldTrace(input)) {
      const snapshot = telemetrySession.snapshot()
      const response = await transport(input, init)
      if (String(input) === `${apiBaseUrl}/auth/session`) acceptSessionResponse(response, snapshot)
      return response
    }
    const owner = telemetrySession.snapshot()
    const method = safeMethod(init?.method ?? (input instanceof Request ? input.method : 'GET'))
    const span = tracer.startSpan('api.request', { kind: SpanKind.CLIENT })
    span.setAttribute('http.request.method', method)
    const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined))
    actionHeaders(span, headers)
    const context = span.spanContext()
    if (context.traceId !== '00000000000000000000000000000000') {
      headers.set('traceparent', `00-${context.traceId}-${context.spanId}-${(context.traceFlags & 1) ? '01' : '00'}`)
      if (context.traceState) headers.set('tracestate', context.traceState.serialize())
    }
    try {
      const response = await transport(input, { ...init, headers })
      acceptSessionResponse(response, owner)
      span.setAttribute('http.response.status_code', response.status)
      if (response.status >= 500) span.setStatus({ code: SpanStatusCode.ERROR })
      return response
    } catch (cause) {
      span.setStatus({ code: SpanStatusCode.ERROR })
      throw cause
    } finally {
      span.end()
    }
  }
}

export async function traceOperation<T>(tracer: Tracer, name: OperationName, action: (within: <R>(call: () => R) => R) => Promise<T>): Promise<T> {
  const actionScope = new ActionScope(name, tracer)
  const span = actionScope.span
  const within = <R>(call: () => R): R => actionScope.within(call)
  span.addEvent(`app.client.${name}.started`)
  try {
    const result = await within(() => action(within))
    span.addEvent(`app.client.${name}.completed`)
    actionScope.finish('success')
    return result
  } catch (cause) {
    span.setStatus({ code: SpanStatusCode.ERROR })
    span.addEvent(`app.client.${name}.failed`)
    const failure=failureOutcome(cause)
    actionScope.finish(failure.outcome,failure.reason)
    throw cause
  } finally {
    actionScope.finish('failed')
  }
}

export const tracedFetch: typeof fetch = (input, init) => createTracedFetch(trace.getTracer('boohtacord/web'), globalThis.fetch)(input, init)
export const tracedOperation = <T>(name: OperationName, action: (within: <R>(call: () => R) => R) => Promise<T>): Promise<T> => traceOperation(trace.getTracer('boohtacord/web'), name, action)
const operations=new WeakMap<Span,ActionScope>()
export function startTracedOperation(name: OperationName): Span {
  const scope=new ActionScope(name),span=scope.span
  operations.set(span,scope)
  span.addEvent(`app.client.${name}.started`)
  return span
}

export function endTracedOperation(span: Span, name: OperationName, failed = false): void {
  if (failed) span.setStatus({ code: SpanStatusCode.ERROR })
  span.addEvent(`app.client.${name}.${failed ? 'failed' : 'completed'}`)
  const scope=operations.get(span)
  if(scope){scope.step(failed?'connect':'ready');scope.finish(failed?'failed':'success',failed?'network':'none');operations.delete(span)}
  else span.end()
}

export function cancelTracedOperation(span:Span):void {const scope=operations.get(span);scope?.cancel();operations.delete(span);if(!scope)span.end()}
export function startTracedCompletion(name: OperationName): { finish: (failed?: boolean) => void; cancel:()=>void; fields:Record<string,string>;traceparent?: string; tracestate?: string } {
  const span = startTracedOperation(name)
  const current = span.spanContext()
  const traceparent = current.traceId === '00000000000000000000000000000000' ? undefined : `00-${current.traceId}-${current.spanId}-${(current.traceFlags & 1) ? '01' : '00'}`
  let ended = false
  const finish = (failed = false) => {
    if (ended) return
    ended = true
    endTracedOperation(span, name, failed)
  }
  const fields:Record<string,string>={},owner=operations.get(span)
  if(owner?.snapshot.binding){
    fields.telemetry_session=owner.snapshot.binding;fields.visit=owner.snapshot.visit;fields.flow=owner.id;
    fields.flow_name=owner.name;fields.attempt=String(owner.attempt)
  }
  return { finish,cancel:()=>{if(!ended){ended=true;cancelTracedOperation(span)}},fields, traceparent, tracestate: current.traceState?.serialize() }
}
