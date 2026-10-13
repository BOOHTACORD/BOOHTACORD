import type { LocalVideoTrack } from 'livekit-client'
import { readScreenShareDiagnostics, type ScreenProfile, type VoiceRoom } from './livekit_gateway'
import type { ScreenDiagnostics } from './screen_diagnostics'
import { tracedOperation } from '../telemetry/client_tracing'
import { activeAction } from '../telemetry/action_scope/scope'
import { ScreenPublisherAdapter } from './screen_publisher/adapter'
import type { ScreenPublisherScope } from './screen_publisher/types'
import { ScreenAdaptationBinding } from './screen_adaptation/runtime_apply/binding'
import type { AdaptationRuntimeOptions } from './screen_adaptation/runtime_apply/types'

export interface ScreenVoiceSession { room: VoiceRoom; screenProfile: ScreenProfile | null }
export class VoiceScreenSession {
  private stopEnded?: () => void
  private watchedRoom?: VoiceRoom
  private repairTimer?: ReturnType<typeof setTimeout>
  private repairGeneration = 0
  private contentMode: 'motion' | 'text' = 'motion'
  private readonly publisher = new ScreenPublisherAdapter<LocalVideoTrack>(() => this.scope())
  private readonly adaptation: ScreenAdaptationBinding<LocalVideoTrack>
  constructor(private readonly current: () => ScreenVoiceSession | null, adaptation: AdaptationRuntimeOptions = {}) {
    this.adaptation = new ScreenAdaptationBinding(this.publisher, adaptation, async profile => {
      const session = this.current()
      if (!session || session !== this.publisher.active?.scope.owner) return
      session.screenProfile = profile; this.scheduleRepairWatchdog(session, profile)
      await session.room.publishScreenProfileMetadata?.(profile, this.contentMode).catch(() => undefined)
    })
  }

  async startScreen(profile: ScreenProfile, mode: 'motion' | 'text' = 'motion'): Promise<ScreenDiagnostics> {
    return tracedOperation('screen.share.start', async (within) => {
      const current = this.requireCurrent(); this.watch(current.room)
      activeAction()?.step('publish')
      const diagnostics = await within(() => this.publisher.start(profile))
      if (this.current() !== current) throw new Error('Голосовое подключение закрыто.')
      this.applyContentMode(mode)
      current.screenProfile = profile; this.scheduleRepairWatchdog(current, profile)
      await current.room.publishScreenProfileMetadata?.(profile, this.contentMode).catch(() => undefined)
      return diagnostics
    })
  }
  async stopScreen(): Promise<void> {
    return tracedOperation('screen.share.stop', async () => {
      const current = this.current()
      this.adaptation.reset()
      this.cancelRepairWatchdog()
      try { await this.publisher.stop() } finally { await current?.room.clearScreenProfileMetadata?.().catch(() => undefined) }
      current?.room.stopScreenProfileChecks?.()
      if (current) current.screenProfile = null
    })
  }
  async updateScreenProfile(profile: ScreenProfile, mode: 'motion' | 'text' = this.contentMode): Promise<ScreenDiagnostics> {
    const current = this.requireCurrent()
    if (!current.screenProfile) throw new Error('Демонстрация экрана не запущена.')
    const previous = current.screenProfile
    let diagnostics: ScreenDiagnostics
    try { diagnostics = await this.publisher.update(profile) }
    catch (cause) {
      if (this.current() === current && previous && this.publisher.active?.profile === previous) await current.room.publishScreenProfileMetadata?.(previous, this.contentMode).catch(() => undefined)
      throw cause
    }
    if (this.current() !== current) throw new Error('Голосовое подключение закрыто.')
    this.applyContentMode(mode)
    current.room.adoptScreenProfile?.(profile); current.screenProfile = profile
    this.scheduleRepairWatchdog(current, profile)
    await current.room.publishScreenProfileMetadata?.(profile, this.contentMode).catch(() => undefined)
    return diagnostics
  }
  async readScreenDiagnostics(): Promise<ScreenDiagnostics> {
    const current = this.current()
    if (!current || !current.screenProfile) throw new Error('Демонстрация экрана не запущена.')
    return this.adaptation.read(() => readScreenShareDiagnostics(current.room))
  }
  cancel(): void {
    this.adaptation.reset()
    this.cancelRepairWatchdog()
    this.publisher.cancel()
    const current = this.current(); if (current) current.screenProfile = null
  }
  private watch(room: VoiceRoom): void {
    if (room === this.watchedRoom) return
    this.stopEnded?.(); this.watchedRoom = room
    this.stopEnded = room.screenPublisher?.onEnded?.(() => {
      const current = this.current()
      if (current?.room !== room || !current.screenProfile) return
      this.cancelRepairWatchdog(); current.screenProfile = null
      void room.clearScreenProfileMetadata?.().catch(() => undefined)
      void this.publisher.submitForEndedEvent().catch(() => {})
    })
  }
  private scheduleRepairWatchdog(session: ScreenVoiceSession, profile: ScreenProfile): void {
    this.cancelRepairWatchdog()
    const generation = this.repairGeneration
    this.repairTimer = setTimeout(() => { void this.inspectForRepair(session, profile, generation) }, 5000)
  }
  private cancelRepairWatchdog(): void {
    ++this.repairGeneration
    if (this.repairTimer) clearTimeout(this.repairTimer)
    this.repairTimer = undefined
  }
  private async inspectForRepair(session: ScreenVoiceSession, profile: ScreenProfile, generation: number): Promise<void> {
    if (!this.watchdogCurrent(session, profile, generation)) return
    try {
      const diagnostics = await readScreenShareDiagnostics(session.room)
      if (this.watchdogCurrent(session, profile, generation) && diagnostics.profileCheck?.status === 'drift') {
        await this.publisher.repairCurrent()
        await session.room.publishScreenProfileMetadata?.(profile, this.contentMode).catch(() => undefined)
      }
    } catch { /* diagnostics and repair status remain available through the regular read path */ }
    if (this.watchdogCurrent(session, profile, generation)) this.repairTimer = setTimeout(() => { void this.inspectForRepair(session, profile, generation) }, 5000)
  }
  private watchdogCurrent(session: ScreenVoiceSession, profile: ScreenProfile, generation: number): boolean {
    return generation === this.repairGeneration && this.current() === session && session.screenProfile === profile && this.publisher.active?.profile === profile
  }
  private scope(): ScreenPublisherScope<LocalVideoTrack> | null {
    const current = this.current(), port = current?.room.screenPublisher
    return current && port ? { owner: current, room: current.room, port } : null
  }
  private applyContentMode(mode: 'motion' | 'text'): void {
    this.contentMode = mode
    const capture = this.publisher.active?.track.mediaStreamTrack
    if (capture && 'contentHint' in capture) capture.contentHint = mode
  }
  private requireCurrent(): ScreenVoiceSession {
    const current = this.current()
    if (!current) throw new Error('Сначала подключитесь к голосовому каналу.')
    return current
  }
}
