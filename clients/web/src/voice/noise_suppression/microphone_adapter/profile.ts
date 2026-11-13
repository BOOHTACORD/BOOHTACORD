import { deepfilterReleaseEnabled, rnnoiseReleaseEnabled } from '../capabilities'
import { browserProcessingConstraints, type AudioProcessingOptions, type NoiseSuppressionFallbackReason } from '../types'
import { browserSuppressionDisabled } from '../deepfilter/capture_guard'

import { MicrophoneAdapterPublication } from './publication'
export abstract class MicrophoneAdapterProfile extends MicrophoneAdapterPublication {
  protected async configure(options: AudioProcessingOptions, generation: number): Promise<void> {
    const mode = options.noiseSuppressionMode
    if (options.noiseSuppressionMode === 'rnnoise' && !rnnoiseReleaseEnabled()) { await this.fallback(options, 'release-disabled', generation); return }
    if (mode === 'deepfilter' && !deepfilterReleaseEnabled()) { await this.fallback(options, 'release-disabled', generation); return }
    try { await this.track!.applyConstraints(browserProcessingConstraints(options)) }
    catch (cause) {
      this.assertCurrent(generation)
      if (mode !== 'rnnoise' && mode !== 'deepfilter') throw cause
      await this.fallback(options, 'unsupported', generation)
      return
    }
    this.assertCurrent(generation)
    if ((mode === 'off' || mode === 'rnnoise' || mode === 'deepfilter') && !browserSuppressionDisabled(this.source)) {
      await this.reacquire(options, generation)
      if (!browserSuppressionDisabled(this.source)) {
        if (mode === 'off') throw new Error('Браузер не подтвердил отключение шумоподавления. Отправка микрофона выключена.')
        await this.fallback(options, 'unsupported', generation); return
      }
    }
    if (mode === 'browser' && this.readCaptureSettings()?.noiseSuppression === false) {
      await this.reacquire(options, generation)
    }
    if (mode !== 'rnnoise' && mode !== 'deepfilter') { this.describeCapture(options); await this.attachControls(options, generation); return }
    this.state = { requestedMode: mode, effectiveMode: 'unknown', status: 'initializing' }
    const processor = this.dependencies.createProcessor({
      onFailure: (reason) => {
        if (!this.closed && generation === this.generation && this.processor === processor)
          this.state = { requestedMode: mode, effectiveMode: 'unknown', status: 'error', fallbackReason: reason }
        this.recoverProcessor(processor, reason, generation)
      },
      onState: (state) => { if (!this.closed && generation === this.generation && this.processor === processor) this.state = { ...state, requestedMode: mode } },
    }, options)
    this.processor = processor
    processor.mute()
    try {
      await this.track!.setProcessor(processor)
      this.assertCurrent(generation)
      if (!processor.processedTrack || this.state.status === 'error') throw new Error('Аудиофильтр не предоставил рабочий выход.')
      if (this.state.status !== 'active') this.state = { ...this.state, requestedMode: mode, effectiveMode: mode, status: 'active', ...(mode === 'deepfilter' ? { modelId: 'deepfilternet3-research-d375b2d' } : {}) }
    } catch (cause) {
      this.assertCurrent(generation)
      const reason = (cause as { reason?: NoiseSuppressionFallbackReason })?.reason ?? this.state.fallbackReason ?? 'processor-error'
      await this.fallback(options, reason, generation)
    }
  }
  protected async attachControls(options: AudioProcessingOptions, generation: number): Promise<void> {
    const processor = this.dependencies.createControlsProcessor?.(options, () => this.failMuted())
    if (!processor) return
    this.processor = processor
    processor.mute()
    await this.track!.setProcessor(processor)
    this.assertCurrent(generation)
    if (!processor.processedTrack) throw new Error('Обработка микрофона не предоставила выход.')
  }
  protected describeCapture(options: AudioProcessingOptions, reason?: NoiseSuppressionFallbackReason): void {
    const reported = this.readCaptureSettings()?.noiseSuppression
    const expected = reason ? 'browser' : options.noiseSuppressionMode
    const effective = reported === undefined ? 'unknown' : reported ? 'browser' : 'off'
    this.state = { requestedMode: options.noiseSuppressionMode, effectiveMode: effective, status: reason ? 'fallback' : effective === expected ? 'active' : 'unsupported', ...(reason ? { fallbackReason: reason } : {}) }
  }
  protected async fallback(options: AudioProcessingOptions, reason: NoiseSuppressionFallbackReason, generation: number): Promise<void> {
    this.silence()
    await this.removeProcessor()
    await this.track!.applyConstraints(browserProcessingConstraints({ ...options, noiseSuppressionMode: 'browser' }))
    this.assertCurrent(generation)
    if (this.readCaptureSettings()?.noiseSuppression !== true) {
      await this.reacquire({ ...options, noiseSuppressionMode: 'browser' }, generation)
      if (this.readCaptureSettings()?.noiseSuppression !== true) throw new Error('Браузер не подтвердил резервное шумоподавление. Отправка микрофона выключена.')
    }
    this.describeCapture(options, reason)
    await this.attachControls(options, generation)
  }
}
