import { describe, expect, it, vi } from 'vitest'
import { InMemorySpanExporter, SimpleSpanProcessor, BasicTracerProvider } from '@opentelemetry/sdk-trace-base'
import { ZoneContextManager } from '@opentelemetry/context-zone'
import { context } from '@opentelemetry/api'
import { createTracedFetch, traceOperation } from './client_tracing'
import { telemetrySession } from './action_scope/session'

describe('manual web tracing', () => {
  it('routine presence responses keep session rejection and installation replacement guards', async () => {
    const provider=new BasicTracerProvider()
    const request=createTracedFetch(provider.getTracer('test'),vi.fn(async()=>new Response(null,{status:401})))
    telemetrySession.reset();telemetrySession.bindInstallation('11111111-1111-4111-8111-111111111111');telemetrySession.bind('1'.repeat(32),'1')
    const path='/api/v1/voice/leases/viewer/screen-viewers/owner'
    await request(path,{method:'GET'})
    expect(telemetrySession.snapshot().binding).toBeNull()
    telemetrySession.bindInstallation('11111111-1111-4111-8111-111111111111');telemetrySession.bind('1'.repeat(32),'1')
    const before=telemetrySession.snapshot()
    const replacement=createTracedFetch(provider.getTracer('test'),vi.fn(async()=>new Response(null,{status:204,headers:{
      'X-Installation-ID':'22222222-2222-4222-8222-222222222222','X-Telemetry-Session':'2'.repeat(32),'X-Telemetry-Schema':'1',
    }})))
    await replacement(path,{method:'PUT'})
    expect(telemetrySession.current(before)).toBe(false)
    expect(telemetrySession.snapshot()).toMatchObject({installation:'22222222-2222-4222-8222-222222222222',binding:'2'.repeat(32)})
    telemetrySession.reset();await provider.shutdown()
  })

  it('does not mark user cancellation as a product error', async () => {
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    await expect(traceOperation(provider.getTracer('test'), 'screen.view', async () => {
      throw new DOMException('private cancellation', 'AbortError')
    })).rejects.toThrow()
    const terminal=exporter.getFinishedSpans().find(span=>span.attributes['app.flow.record']==='terminal')!
    expect(terminal.attributes['app.flow.outcome']).toBe('cancelled')
    expect(terminal.status.code).not.toBe(2)
    await provider.shutdown()
  })

  it('omits successful unscoped presence polling while retaining errors, stop and action requests', async () => {
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    const transport = vi.fn(async () => new Response(null, { status: 204 })) as unknown as typeof fetch
    const request = createTracedFetch(provider.getTracer('test'), transport)
    const path='/api/v1/voice/leases/private-viewer/screen-viewers/private-owner'
    for(let i=0;i<12;i++) {await request(path,{method:'GET'});await request(path,{method:'PUT'})}
    expect(exporter.getFinishedSpans()).toHaveLength(0)
    ;(transport as ReturnType<typeof vi.fn>).mockResolvedValueOnce(new Response(null,{status:503}))
    await request(path,{method:'PUT'})
    ;(transport as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new DOMException('private-timeout','TimeoutError'))
    await expect(request(path,{method:'GET'})).rejects.toThrow()
    await request(path,{method:'DELETE'})
    expect(exporter.getFinishedSpans()).toHaveLength(3)
    expect(exporter.getFinishedSpans().slice(0,2).every(span=>span.status.code===2)).toBe(true)
    expect(JSON.stringify(exporter.getFinishedSpans().map(span=>span.attributes))).not.toContain('private-')
    await provider.shutdown()
  })

  it('links an API call without recording its URL, body or credentials', async () => {
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    const transport = vi.fn(async () => new Response(null, { status: 204 })) as unknown as typeof fetch
    const request = createTracedFetch(provider.getTracer('test'), transport)
    await request('/api/v1/direct-messages/private-id?token=query-secret', {
      method: 'POST', body: 'private-message', headers: { cookie: 'session=cookie-secret' },
    })
    const [url, init] = (transport as ReturnType<typeof vi.fn>).mock.calls[0] as [string, RequestInit]
    expect(url).toContain('private-id')
    expect(new Headers(init.headers).get('traceparent')).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-01$/)
    const spans = exporter.getFinishedSpans()
    expect(spans).toHaveLength(1)
    expect(spans[0].name).toBe('api.request')
    const visible = JSON.stringify({ name: spans[0].name, attributes: spans[0].attributes, status: spans[0].status })
    for (const secret of ['private-id', 'query-secret', 'private-message', 'cookie-secret']) expect(visible).not.toContain(secret)
    await provider.shutdown()
  })

  it('records a fixed voice operation and strips error details', async () => {
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    await expect(traceOperation(provider.getTracer('test'), 'voice.join', async () => {
      throw new Error('private voice token')
    })).rejects.toThrow('private voice token')
    const span = exporter.getFinishedSpans().find(span => span.attributes['app.flow.record'] === 'terminal')!
    expect(span.name).toBe('voice.join')
    expect(span.events.map((event) => event.name)).toEqual(['app.client.voice.join.started', 'app.client.voice.join.failed'])
    expect(JSON.stringify({ name: span.name, attributes: span.attributes, status: span.status, events: span.events })).not.toContain('private voice token')
    await provider.shutdown()
  })

  it('parents the immediate API call under its explicit voice operation', async () => {
    context.setGlobalContextManager(new ZoneContextManager().enable())
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    const tracer = provider.getTracer('test')
    const request = createTracedFetch(tracer, vi.fn(async () => new Response(null, { status: 204 })) as unknown as typeof fetch)
    await traceOperation(tracer, 'voice.join', async (within) => {
      await Promise.resolve()
      return within(() => request('/api/v1/voice/leases/viewer/screen-viewers/owner', { method: 'PUT' }))
    })
    const api = exporter.getFinishedSpans().find(span => span.name === 'api.request')!
    const voice = exporter.getFinishedSpans().find(span => span.attributes['app.flow.record'] === 'terminal')!
    expect(voice.events.map((event) => event.name)).toEqual(['app.client.voice.join.started', 'app.client.voice.join.completed'])
    expect(api.spanContext().traceId).toBe(voice.spanContext().traceId)
    expect(api.parentSpanContext?.spanId).toBe(voice.spanContext().spanId)
    await provider.shutdown()
    context.disable()
  })

  it('does not trace operational requests or export its own OTLP batches', async () => {
    const exporter = new InMemorySpanExporter()
    const provider = new BasicTracerProvider({ spanProcessors: [new SimpleSpanProcessor(exporter)] })
    const transport = vi.fn(async () => new Response(null, { status: 202 })) as unknown as typeof fetch
    const request = createTracedFetch(provider.getTracer('test'), transport)
    for (const path of ['/api/v1/health', '/api/v1/maintenance', '/api/v1/maintenance/events', '/api/v1/telemetry/traces', '/api/v1/voice/rosters/events']) {
      await request(path)
    }
    expect(exporter.getFinishedSpans()).toHaveLength(0)
    expect((transport as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(5)
    await provider.shutdown()
  })
})
