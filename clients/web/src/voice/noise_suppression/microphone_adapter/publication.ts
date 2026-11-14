import { microphoneConstraints, microphonePublishOptions } from '../../media_publishing'
import { type AudioProcessingOptions } from '../types'
import { inputConstraints, missingAudioInput } from '../../audio_input_selection'

import { MicrophoneAdapterState } from './state'
export abstract class MicrophoneAdapterPublication extends MicrophoneAdapterState {
  protected async create(options: AudioProcessingOptions, generation: number): Promise<void> {
    try {
      let fallback = false
      try { this.track = await this.dependencies.createTrack({ ...microphoneConstraints(options), ...inputConstraints(this.deviceId) }) }
      catch (cause) {
        this.assertCurrent(generation)
        if (this.deviceId === 'default' || !missingAudioInput(cause)) throw cause
        this.track = await this.dependencies.createTrack(microphoneConstraints(options))
        this.deviceId = 'default'
        fallback = true
      }
      this.source = this.track.mediaStreamTrack
      this.silence()
      this.assertCurrent(generation)
      await this.track.mute()
      await this.configure(options, generation)
      this.assertCurrent(generation)
      await this.publishMuted(generation)
      this.options = options
      this.watchSource()
      this.confirmInput(fallback ? 'fallback' : 'success', 'prejoin', fallback ? 'Сохранённый микрофон недоступен. Используется системный микрофон.' : undefined)
    } catch (cause) {
      await this.cleanup()
      this.state = { requestedMode: options.noiseSuppressionMode, effectiveMode: 'unknown', status: 'error' }
      if (!this.closed) this.confirmInput('error', 'prejoin', 'Не удалось включить микрофон. Отправка звука выключена.')
      throw cause
    }
  }
  protected async publishMuted(generation: number): Promise<void> {
    if (this.published) return
    this.silence()
    try {
      try { await this.dependencies.publishTrack(this.track!, microphonePublishOptions) }
      catch (cause) {
        this.assertCurrent(generation)
        if (!(cause instanceof Error) || cause.message !== 'Cancelled publication by calling unpublish' || !this.dependencies.isReconnecting?.()) throw cause
        this.silence()
        await this.dependencies.publishTrack(this.track!, microphonePublishOptions)
      }
    } catch (cause) {
      this.silence()
      try { await this.dependencies.unpublishTrack(this.track!) }
      catch { this.failMuted() }
      throw cause
    }
    this.published = true
    this.assertCurrent(generation)
  }
  protected async reacquire(options: AudioProcessingOptions, generation: number): Promise<void> {
    const old = this.track
    this.stopEnded?.(); this.stopEnded = undefined
    this.silence()
    if (old) {
      await old.mute()
      if (this.published) {
        try { await this.dependencies.unpublishTrack(old); this.published = false }
        catch (cause) { this.failMuted(); throw cause }
      }
      old.stop(); this.track = undefined; this.source = undefined
    }
    this.assertCurrent(generation)
    const next = await this.dependencies.createTrack({ ...microphoneConstraints(options), ...inputConstraints(this.deviceId) })
    // A late capture is never published or left live after disposal.
    if (this.closed || generation !== this.generation) { next.mediaStreamTrack.enabled = false; next.stop(); this.assertCurrent(generation) }
    this.track = next; this.source = next.mediaStreamTrack
    this.silence()
    await next.mute()
    this.assertCurrent(generation)
  }
  dispose(): Promise<void> {
    if (this.closed) return this.queue.then(() => undefined)
    // Revoke before waiting for a pending create/init/recovery to settle.
    this.closed = true
    this.listeners.clear()
    this.inputListeners.clear()
    this.generation++
    this.desiredEnabled = false
    this.silence()
    const cleanup = this.queue.catch(() => undefined).then(() => this.cleanup())
    this.queue = cleanup
    return cleanup
  }
  protected async cleanup(): Promise<void> {
    this.stopEnded?.()
    this.stopEnded = undefined
    const track = this.track
    this.silence()
    try { await this.removeProcessor() } finally {
      if (track) {
        try { if (this.published) await this.dependencies.unpublishTrack(track) }
        finally { track.stop() }
      }
      this.track = undefined; this.source = undefined; this.published = false
    }
  }
}
