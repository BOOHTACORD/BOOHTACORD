import { microphoneConstraints } from '../../media_publishing'
import { inputConstraints, type AudioInputPhase } from '../../audio_input_selection'

import { MicrophoneAdapterIntent } from './intent'
export abstract class MicrophoneAdapterDevice extends MicrophoneAdapterIntent {
  reapplyDevice(): Promise<boolean> { return this.switchDevice(this.deviceId, 'reconnect', true) }
  prepareReconnect(): void { this.silence() }
  switchDevice(deviceId: string, phase: AudioInputPhase = 'active', force = false, fallbackWarning?: string): Promise<boolean> {
    return this.enqueue(async (generation) => {
      if (phase === 'reconnect') deviceId = this.deviceId
      const previous = this.deviceId
      const stopOnUncertainRemoval = (error: unknown) => {
        if (this.state.status === 'error' && !this.desiredEnabled) {
          this.confirmInput('error', phase, 'Микрофон недоступен. Отправка звука выключена. Выберите устройство и включите микрофон снова.')
          throw error
        }
      }
      if (!force && previous === deviceId && this.inputValue.outcome === 'success') return true
      if (!this.track) {
        this.deviceId = deviceId
        this.confirmInput(fallbackWarning ? 'fallback' : 'success', phase, fallbackWarning)
        return true
      }
      this.silence()
      this.stopEnded?.()
      this.stopEnded = undefined
      try {
        await this.restartInput(deviceId, generation)
        this.deviceId = deviceId
        this.confirmInput(fallbackWarning ? 'fallback' : 'success', phase, fallbackWarning)
        return true
      } catch (cause) {
        this.assertCurrent(generation)
        stopOnUncertainRemoval(cause)
        for (const fallback of [...new Set([previous, 'default'])]) {
          try {
            await this.restartInput(fallback, generation)
            this.deviceId = fallback
            this.confirmInput('fallback', phase, fallback === previous ? 'Не удалось переключить микрофон. Сохранён предыдущий источник.' : 'Выбранный микрофон недоступен. Используется системный микрофон.')
            return false
          } catch (error) {
            this.assertCurrent(generation)
            stopOnUncertainRemoval(error)
          }
        }
        this.failMuted()
        this.confirmInput('error', phase, 'Микрофон недоступен. Отправка звука выключена. Выберите устройство и включите микрофон снова.')
        throw cause
      }
    })
  }
  protected async restartInput(deviceId: string, generation: number): Promise<void> {
    this.assertCurrent(generation)
    await this.track!.mute()
    this.silence()
    await this.removeProcessor()
    this.assertCurrent(generation)
    await this.track!.restartTrack({ ...microphoneConstraints(this.options), ...inputConstraints(deviceId) })
    this.source = this.track!.mediaStreamTrack
    this.silence()
    this.assertCurrent(generation)
    const previous = this.deviceId
    this.deviceId = deviceId
    try { await this.configure(this.options, generation); await this.publishMuted(generation) }
    finally { this.deviceId = previous }
    await this.restoreIntent(generation)
    this.watchSource()
  }
}
