import { expect,it,vi } from 'vitest'
import { trace } from '@opentelemetry/api'
import { BasicTracerProvider, InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { setScreenViewerPresence } from './screen_viewer_presence'
it('the default presence transport retains failures but emits no heartbeat-success spans',async()=>{
 const exporter=new InMemorySpanExporter(),provider=new BasicTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]})
 trace.setGlobalTracerProvider(provider)
 const request=vi.fn(async()=>new Response(null,{status:204}));vi.stubGlobal('fetch',request)
 const viewer='11111111-1111-4111-8111-111111111111',owner='22222222-2222-4222-8222-222222222222'
 try {
  await setScreenViewerPresence(viewer,owner,'track',true)
  expect(exporter.getFinishedSpans()).toHaveLength(0)
  request.mockResolvedValueOnce(new Response(null,{status:503}))
  await expect(setScreenViewerPresence(viewer,owner,'track',true)).rejects.toThrow()
  expect(exporter.getFinishedSpans()).toHaveLength(1)
  expect(exporter.getFinishedSpans()[0].status.code).toBe(2)
 }finally {vi.unstubAllGlobals();trace.disable();await provider.shutdown()}
})
