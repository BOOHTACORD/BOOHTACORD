import type { VoiceConnectionObserver } from './voice_session'
import { type Span } from '@opentelemetry/api'
import { endTracedOperation, startTracedOperation,cancelTracedOperation } from '../telemetry/client_tracing'

export interface ReconnectableVoiceRoom {
  on(event: 'reconnecting' | 'reconnected' | 'disconnected', listener: (reason?: number) => void): unknown
}

export class VoiceReconnectMonitor {
  private leaving = false
  private reconnectSpan: Span | null = null
  private observer: VoiceConnectionObserver | null = null

  setObserver(observer: VoiceConnectionObserver): void {
    this.observer = observer
  }

  notifyAdmitted(leaseID: string, channelID: string): void { this.observer?.admitted?.(leaseID, channelID) }
  private interruptReconnect(): void {
    this.reconnectSpan?.addEvent('app.client.voice.reconnect.interrupted')
    if(this.reconnectSpan)cancelTracedOperation(this.reconnectSpan); this.reconnectSpan = null
  }
  notifyDisconnected(reason?: number): void {
    this.interruptReconnect()
    this.observer?.disconnected(reason)
  }

  private finishReconnect(failed = false): void {
    if (this.reconnectSpan) endTracedOperation(this.reconnectSpan, 'voice.reconnect', failed)
    this.reconnectSpan = null
  }

  async whileLeaving(action: () => Promise<void>): Promise<void> {
    this.interruptReconnect()
    this.leaving = true
    try { await action() } finally { this.leaving = false }
  }

  bind(room: ReconnectableVoiceRoom, current: () => boolean, disconnected: (reason?: number) => Promise<void>): void {
    room.on('reconnecting', () => { if (current() && !this.leaving) { this.reconnectSpan ??= startTracedOperation('voice.reconnect'); this.observer?.reconnecting() } })
    room.on('reconnected', () => { if (current()) { this.finishReconnect(); this.observer?.reconnected() } })
    room.on('disconnected', (reason) => {
      if (current() && !this.leaving) void disconnected(reason)
    })
  }
}
