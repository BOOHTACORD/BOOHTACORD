import type { LocalAudioTrack } from 'livekit-client'
import { defaultAudioProcessing } from '../../media_publishing'
import type { BrowserAudioProcessingSettings } from '../../audio_processing_diagnostics'
import { type AudioProcessingOptions, type NoiseSuppressionFallbackReason, type NoiseSuppressionRuntimeState, type NoiseSuppressionMode } from '../types'
import { type AudioInputPhase, type AudioInputSelection } from '../../audio_input_selection'
import { reportAudioInputSwitch } from '../../audio_input_reporting'

import type { MicrophoneProcessor, MicrophoneAdapterDependencies } from './contracts'
export abstract class MicrophoneAdapterState {
  protected queue: Promise<unknown> = Promise.resolve()
  protected generation = 0
  protected closed = false
  protected desiredEnabled = false
  protected track?: LocalAudioTrack
  protected source?: MediaStreamTrack
  protected processor?: MicrophoneProcessor
  protected published = false
  protected options: AudioProcessingOptions = { ...defaultAudioProcessing }
  protected deviceId = 'default'
  protected inputValue: AudioInputSelection = { deviceId: 'default', outcome: 'success' }
  protected readonly inputListeners = new Set<(selection: AudioInputSelection) => void>()
  protected stopEnded: (() => void) | undefined
  protected readonly listeners = new Set<(state: NoiseSuppressionRuntimeState) => void>()
  protected stateValue: NoiseSuppressionRuntimeState = { requestedMode: 'browser', effectiveMode: 'unknown', status: 'idle' }
  protected abstract silence(): void
  protected abstract cleanup(): Promise<void>
  protected abstract create(options: AudioProcessingOptions, generation: number): Promise<void>
  protected abstract configure(options: AudioProcessingOptions, generation: number): Promise<void>
  protected abstract restoreIntent(generation: number): Promise<void>
  protected abstract removeProcessor(): Promise<void>
  protected abstract failMuted(reason?: NoiseSuppressionFallbackReason): void
  protected abstract recoverProcessor(processor: MicrophoneProcessor, reason: NoiseSuppressionFallbackReason, generation: number, failedMode: NoiseSuppressionMode): void
  protected abstract changeProfile(options: AudioProcessingOptions, generation: number): Promise<void>
  protected abstract watchSource(): void
  abstract switchDevice(deviceId: string, phase?: AudioInputPhase, force?: boolean, fallbackWarning?: string): Promise<boolean>
  constructor(protected readonly dependencies: MicrophoneAdapterDependencies) {}
  protected get state(): NoiseSuppressionRuntimeState { return this.stateValue }
  protected set state(value: NoiseSuppressionRuntimeState) { this.stateValue = value; for (const listener of this.listeners) listener({ ...value }) }
  subscribe(listener: (state: NoiseSuppressionRuntimeState) => void): () => void {
    if (this.closed) return () => undefined
    this.listeners.add(listener)
    listener(this.runtimeState)
    return () => this.listeners.delete(listener)
  }
  get runtimeState(): NoiseSuppressionRuntimeState { return { ...this.state } }
  readCaptureSettings(): BrowserAudioProcessingSettings | undefined { return (this.processor?.sourceTrack ?? this.source)?.getSettings() }
  readOutputTrack(): MediaStreamTrack | undefined { return this.track?.mediaStreamTrack }
  get inputSelection(): AudioInputSelection { return { ...this.inputValue } }
  subscribeInput(listener: (selection: AudioInputSelection) => void): () => void {
    if (this.closed) return () => undefined
    this.inputListeners.add(listener)
    return () => this.inputListeners.delete(listener)
  }
  protected confirmInput(outcome: AudioInputSelection['outcome'], phase: AudioInputPhase, warning?: string): void {
    this.inputValue = { deviceId: this.deviceId, outcome, ...(warning ? { warning } : {}) }
    reportAudioInputSwitch(phase, outcome)
    for (const listener of this.inputListeners) listener(this.inputSelection)
  }
  protected enqueue<T>(operation: (generation: number) => Promise<T>): Promise<T> {
    if (this.closed) return Promise.reject(new Error('Голосовое подключение закрыто.'))
    const generation = this.generation
    const result = this.queue.catch(() => undefined).then(async () => { this.assertCurrent(generation); return operation(generation) })
    this.queue = result
    return result
  }
  protected assertCurrent(generation: number): void {
    if (this.closed || generation !== this.generation) throw new Error('Голосовое подключение закрыто.')
  }
}
