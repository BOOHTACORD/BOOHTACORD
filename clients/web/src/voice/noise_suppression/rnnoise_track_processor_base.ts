import type { AudioProcessorOptions } from 'livekit-client'
import workletUrl from './rnnoise.worklet.ts?worker&url'
import { supportsRnnoise, supportedContextRate } from './capabilities'
import { loadRnnoiseAssets } from './rnnoise_loader'
import { readRnnoiseCounters } from './diagnostics'
import type { NoiseSuppressionFallbackReason } from './types'
import { captureRate, initializationDuration } from './rnnoise_timing'
import { RnnoiseTrackLifecycle } from './rnnoise_track_lifecycle'

export class RnnoiseTrackProcessorBase extends RnnoiseTrackLifecycle {
  async init(opts: AudioProcessorOptions): Promise<void> {
    const initStarted = performance.now()
    const generation = ++this.generation
    this.failed = false
    this.muted = true
    this.sourceTrack = opts.track
    const captureSampleRate = captureRate(opts.track)
    this.update({ status: 'initializing', effectiveMode: 'unknown', fallbackReason: undefined, captureSampleRate, initDurationMs: undefined })
    let reason: NoiseSuppressionFallbackReason = 'unsupported'
    try {
      if (!supportsRnnoise()) throw new Error('RNNoise unsupported')
      reason = 'sample-rate'
      this.update({ contextSampleRate: opts.audioContext.sampleRate })
      if (!supportedContextRate(opts.audioContext)) throw new Error('RNNoise requires 48 kHz context')
      reason = 'asset-load'
      const assets = await this.bounded((this.options.loadAssets ?? loadRnnoiseAssets)())
      if (generation !== this.generation) return
      reason = 'init-timeout'
      await this.bounded(opts.audioContext.audioWorklet.addModule(this.options.workletUrl ?? workletUrl))
      if (generation !== this.generation) return
      reason = 'processor-error'
      const node = new AudioWorkletNode(opts.audioContext, 'boohtacord-rnnoise', {
        numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1], channelCount: 1,
        channelCountMode: 'explicit', processorOptions: { module: assets.module },
      })
      this.worklet = node
      node.onprocessorerror = () => this.fail('processor-error')
      reason = 'init-timeout'
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('RNNoise initialization timeout')), this.options.initTimeoutMs ?? 8000)
        this.cancelInit = () => { clearTimeout(timer); resolve() }
        node.port.onmessage = event => {
          if (generation !== this.generation) return
          if (event.data.type === 'unmuted') this.acknowledgeUnmute?.(event.data.intent)
          if (event.data.type === 'ready') { clearTimeout(timer); this.cancelInit = undefined; resolve() }
          if (event.data.type === 'health') {
            const counters = readRnnoiseCounters(event.data)
            if (!counters) { this.fail('processor-error'); return }
            this.update(counters)
            if (counters.processorErrors) this.fail('processor-error')
            else if (counters.fifoOverruns || counters.fifoUnderruns > 48000) this.fail('overload')
          }
        }
      })
      if (generation !== this.generation) return
      reason = 'processor-error'
      this.source = opts.audioContext.createMediaStreamSource(new MediaStream([opts.track]))
      this.destination = opts.audioContext.createMediaStreamDestination()
      this.processedTrack = this.destination.stream.getAudioTracks()[0]
      this.processedTrack.enabled = !this.muted
      node.port.postMessage({ type: this.muted ? 'mute' : 'unmute' })
      this.source.connect(node); node.connect(this.destination)
      this.update({ status: 'active', effectiveMode: 'rnnoise', modelId: assets.modelId })
    } catch (error) {
      if (generation === this.generation) {
        this.fail(reason)
        this.releaseGraph()
        throw error
      }
    } finally {
      if (generation === this.generation) {
        this.update({ initDurationMs: initializationDuration(initStarted) })
      }
    }
  }
  async restart(opts: AudioProcessorOptions): Promise<void> {
    await this.destroy()
    await this.init(opts)
  }
}
