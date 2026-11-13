import { defineStore } from 'pinia'
import { ref } from 'vue'
import { loadCurrentSession } from '../identity/current_session'
import { parseRealtimeEvent, realtimeTraceURL, realtimeURL, NewRealtimeEnvelopeError, type RealtimeEvent } from './realtime_client'
import { createRealtimeDelivery, type EventHandler } from './realtime_event_delivery'
import { createCoalescedDelivery } from './hint_batch/controller'
import { createReconnectSchedule } from './reconnect_schedule/controller'
import type { RealtimeConnectOptions, RealtimeSocket, RealtimeSocketFactory } from './realtime_connection_types'
import { startTracedCompletion } from '../telemetry/client_tracing'
import { boundedSessionCheck, createSocketAttempt, createProtocolFallback } from './socket_attempt'
export type { RealtimeConnectOptions, RealtimeSocket, RealtimeSocketFactory } from './realtime_connection_types'
export type RealtimeState = 'IDLE' | 'CONNECTING' | 'CONNECTED' | 'DISCONNECTED' | 'ERROR'
export const useRealtimeStore = defineStore('realtime', () => {
  const state = ref<RealtimeState>('IDLE')
  const error = ref<string | null>(null)
  let socket: RealtimeSocket | null = null
  let stopSchedule = () => {}
  let active = false, generation = 0
  let delivery: Pick<ReturnType<typeof createRealtimeDelivery>, 'accept' | 'cursor' | 'disconnected' | 'reset'> | null = null
  let pendingConnection: (() => void) | null = null, retryNow: (() => void) | null = null
  let endSocketAttempt = () => {}, cancelSession = () => {}
  function connect(onEvent: EventHandler, factory?: RealtimeSocketFactory, url?: string, options: RealtimeConnectOptions = {}): void {
    if (active) return
    active = true
    const ownGeneration = ++generation, attempt = createSocketAttempt(options), protocol = factory ? null : createProtocolFallback(); let attemptNumber = 0
    endSocketAttempt = attempt.end
    const retry = createReconnectSchedule(open, options.random); stopSchedule = retry.stop
    state.value = 'CONNECTING'; error.value = null
    const failure = (cause: unknown) => {
      if (ownGeneration !== generation) return
      error.value = cause instanceof Error ? cause.message : 'РќРµ СѓРґР°Р»РѕСЃСЊ РѕР±РЅРѕРІРёС‚СЊ РґР°РЅРЅС‹Рµ РїРѕСЃР»Рµ РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёСЏ СЃРІСЏР·Рё.'
      state.value = 'ERROR'
      if (socket) fail(socket)
    }
    delivery = options.onHintBatch ? createCoalescedDelivery(onEvent, options.onRecovery, failure, options.onHintBatch) : createRealtimeDelivery(onEvent, options.onRecovery, failure)
    function schedule(): void {
      if (active && ownGeneration === generation) retry.schedule()
    }
    async function checkAndRetry(failedAttempt: number): Promise<void> {
      let valid: boolean | null = null; const pending = boundedSessionCheck(options.checkSession ?? (async signal => (await loadCurrentSession(undefined, signal)) !== null)); cancelSession = pending.cancel
      try { valid = await pending.result }
      catch { /* A network failure does not prove session revocation. */ } finally { if (cancelSession === pending.cancel) cancelSession = () => {} }
      if (!active || ownGeneration !== generation || failedAttempt !== attemptNumber) return
      if (valid === false) {
        disconnect()
        options.onSessionExpired?.()
        return
      }
      schedule()
    }
    function fail(current: RealtimeSocket): void {
      if (!active || socket !== current || ownGeneration !== generation) return
      socket = null; attempt.end(); protocol?.failed(current)
      delivery?.disconnected()
      state.value = 'DISCONNECTED'
      error.value ??= 'Realtime-СЃРѕРµРґРёРЅРµРЅРёРµ РЅРµРґРѕСЃС‚СѓРїРЅРѕ. РџРѕРІС‚РѕСЂСЏРµРј РїРѕРґРєР»СЋС‡РµРЅРёРµ.'
      current.close()
      void checkAndRetry(attemptNumber)
    }
    function open(): void {
      if (!active || ownGeneration !== generation || socket) return
      attemptNumber++; attempt.begin()
      const operation = retry.attempt() === 0 ? 'realtime.connect' : 'realtime.reconnect'
      const { finish,cancel,fields, traceparent, tracestate } = startTracedCompletion(operation)
      pendingConnection = cancel
      state.value = 'CONNECTING'
      let current: RealtimeSocket
      try {
        const target = url ?? realtimeURL()
        const after = delivery?.cursor()
        current = (factory ?? protocol!.open)(realtimeTraceURL(after ? `${target}${target.includes('?') ? '&' : '?'}after=${encodeURIComponent(after)}` : target, traceparent, tracestate,fields))
      } catch (cause) {
        attempt.end(); finish(true)
        error.value = cause instanceof Error ? cause.message : 'Realtime-СЃРѕРµРґРёРЅРµРЅРёРµ РЅРµРґРѕСЃС‚СѓРїРЅРѕ.'
        state.value = 'DISCONNECTED'
        schedule()
        return
      }
      socket = current; attempt.watch(current, () => fail(current)); attempt.arm(() => { finish(true); fail(current) })
      current.onopen = () => { if (socket === current) { protocol?.connected(current); state.value = 'CONNECTED'; error.value = null } }
      current.onmessage = (message) => {
        if (socket !== current) return
        try {
          const event: RealtimeEvent = parseRealtimeEvent(JSON.parse(message.data)); if (!attempt.observe(event.kind)) { fail(current); return }
          if (event.kind === 'connection.heartbeat') return
          if (event.kind === 'connection.ready') {attempt.ready();finish();retry.ready()}
          delivery?.accept(event)
        } catch (cause) { if (cause instanceof NewRealtimeEnvelopeError) { fail(current); return }
          error.value = cause instanceof Error ? cause.message : 'РќРµРєРѕСЂСЂРµРєС‚РЅРѕРµ realtime-СЃРѕР±С‹С‚РёРµ.'
          state.value = 'ERROR'
        }
      }
      current.onerror = () => { finish(true); fail(current) }
      current.onclose = () => { finish(true); fail(current) }
    }
    retryNow = () => {
      if (!active || ownGeneration !== generation) return
      retry.stop(); cancelSession()
      const current = socket
      socket = null; attempt.end()
      current?.close()
      delivery?.disconnected()
      open()
    }
    open()
  }
  function disconnect(): void {
    active = false; cancelSession(); endSocketAttempt(); endSocketAttempt = () => {}
    generation++; stopSchedule()
    delivery?.reset(); delivery = null
    const current = socket
    socket = null
    pendingConnection?.(); pendingConnection = null
    retryNow = null
    if (current) { current.onclose = null; current.onerror = null; current.onmessage = null; current.onopen = null; current.close() }
    state.value = 'DISCONNECTED'
    error.value = null
  }
  return { connect, disconnect, reconnect: () => retryNow?.(), error, state }
})
