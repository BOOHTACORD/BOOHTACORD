import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { context, trace } from '@opentelemetry/api'
import { ZoneContextManager } from '@opentelemetry/context-zone'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { ActionScope, activeAction } from './scope'
import { TelemetrySession } from './session'
import { SessionProcessor } from '../export_session/processor'

beforeEach(()=>context.setGlobalContextManager(new ZoneContextManager().enable()))
afterEach(()=>context.disable())

it('detaches a stale nested scope but preserves a fresh ambient action',async()=>{
 const session=new TelemetrySession();session.bind('1'.repeat(32),'1')
 const exporter=new InMemorySpanExporter(),provider=new BasicTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]})
 const old=new ActionScope('message.send',provider.getTracer('test'),session)
 await old.within(async()=>{
  session.reset();session.bind('2'.repeat(32),'1')
  await old.within(async()=>{
   expect(activeAction()).toBeUndefined()
   expect(trace.getSpan(context.active())).toBeUndefined()
   await Promise.resolve()
  })
  const fresh=new ActionScope('voice.join',provider.getTracer('test'),session)
  fresh.within(()=>old.within(()=>{
   expect(activeAction()).toBe(fresh)
   expect(trace.getSpan(context.active())).toBe(fresh.span)
  }))
  fresh.finish('success')
 })
 await provider.shutdown()
})

it('rejects late children of the old account without dropping an explicit fresh root',async()=>{
 const session=new TelemetrySession();session.bind('1'.repeat(32),'1')
 const send=vi.fn(async()=>new Response(null,{status:202}))
 const processor=new SessionProcessor(session,send),provider=new BasicTracerProvider({spanProcessors:[processor]})
 const old=new ActionScope('message.send',provider.getTracer('test'),session)
 old.within(()=>{
  session.reset();session.bind('2'.repeat(32),'1')
  provider.getTracer('test').startSpan('api.request').end()
 })
 await processor.forceFlush();expect(send.mock.calls.length).toBe(0)
 context.with(old.context,()=>{
  const fresh=new ActionScope('voice.join',provider.getTracer('test'),session)
  fresh.finish('success')
 })
 await processor.forceFlush();expect(send).toHaveBeenCalledOnce()
 await provider.shutdown()
})
