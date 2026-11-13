import type { AudioProcessorOptions, Track, TrackProcessor } from 'livekit-client'
import { loadDeepFilterAssets } from './asset_loader'
import { disposePort } from './dispose_port'

type Assets = Awaited<ReturnType<typeof loadDeepFilterAssets>>
type Options = { loadAssets?: (signal: AbortSignal) => Promise<Assets>; onFailure?: () => void; timeoutMs?: number }

/** Research graph only. The caller owns capture, context and final track enablement. */
export class DeepFilterTrackProcessor implements TrackProcessor<Track.Kind.Audio, AudioProcessorOptions> {
  readonly name = 'deepfilter-research'
  sourceTrack?: MediaStreamTrack
  processedTrack?: MediaStreamTrack
  private source?: MediaStreamAudioSourceNode
  private destination?: MediaStreamAudioDestinationNode
  private node?: AudioWorkletNode
  private generation = 0
  private intent = 0
  private failed = false
  private preparation?: AbortController
  private disposal?: Promise<void>
  private ready?: () => void
  private cancelReady?: () => void
  private acknowledge?: (intent: unknown) => void
  private cancelUnmute?: (error?: Error) => void
  constructor(private readonly options: Options = {}) {}

  private async bounded<T>(promise: Promise<T>, signal?: AbortSignal): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined
    let cancel: (() => void) | undefined
    try { return await Promise.race([promise, new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new Error('processor timeout')), this.options.timeoutMs ?? 15000)
      cancel = () => reject(new Error('processor cancelled'))
      if (signal?.aborted) cancel(); else signal?.addEventListener('abort', cancel, { once: true })
    })]) } finally { if (timer) clearTimeout(timer); if (cancel) signal?.removeEventListener('abort', cancel) }
  }

  private fail(): void {
    if (this.failed) return
    this.failed = true
    if (this.processedTrack) this.processedTrack.enabled = false
    this.cancelReady?.()
    this.cancelUnmute?.(new Error('processor failed'))
    this.node?.port.postMessage({ type: 'mute' })
    this.options.onFailure?.()
  }

  async init(opts: AudioProcessorOptions): Promise<void> {
    if (this.sourceTrack) throw new Error('processor already initialized')
    const generation = ++this.generation
    if (this.disposal) await this.disposal
    if (generation !== this.generation) return
    const preparation = this.preparation = new AbortController()
    this.failed = false; this.sourceTrack = opts.track
    try {
      if (opts.audioContext.sampleRate !== 48000) throw new Error('DeepFilter requires 48 kHz')
      const assets = await this.bounded((this.options.loadAssets ?? (signal => loadDeepFilterAssets(15000, signal)))(preparation.signal), preparation.signal)
      if (generation !== this.generation) return
      await this.bounded(opts.audioContext.audioWorklet.addModule('/audio/deepfilternet/research-d375b2d/deepfilter/worklet.js'), preparation.signal)
      if (generation !== this.generation) return
      const entropy = crypto.getRandomValues(new Uint8Array(65536))
      const node = new AudioWorkletNode(opts.audioContext, 'boohtacord-deepfilter-research', {
        numberOfInputs: 1, numberOfOutputs: 1, channelCount: 1, channelCountMode: 'explicit',
        outputChannelCount: [1], processorOptions: { module: assets.module, model: assets.model, attenuation: 25, entropy },
      })
      entropy.fill(0); this.node = node
      node.onprocessorerror = () => this.fail()
      node.port.onmessage = event => {
        if (generation !== this.generation) return
        if (event.data.type === 'ready') this.ready?.()
        else if (event.data.type === 'unmuted') this.acknowledge?.(event.data.intent)
        else if (event.data.type === 'error') this.fail()
      }
      await this.bounded(new Promise<void>(resolve => { this.ready = resolve; this.cancelReady = resolve }), preparation.signal)
      this.ready = undefined; this.cancelReady = undefined
      if (generation !== this.generation) return
      if (this.failed) throw new Error('processor failed')
      this.source = opts.audioContext.createMediaStreamSource(new MediaStream([opts.track]))
      this.destination = opts.audioContext.createMediaStreamDestination()
      this.processedTrack = this.destination.stream.getAudioTracks()[0]
      if (!this.processedTrack) throw new Error('output unavailable')
      this.processedTrack.enabled = false
      this.source.connect(node); node.connect(this.destination)
    } catch (error) {
      if (generation === this.generation) { this.fail(); await this.destroy(); throw error }
    }
  }

  mute(): void {
    this.intent++; this.cancelUnmute?.()
    if (this.processedTrack) this.processedTrack.enabled = false
    this.node?.port.postMessage({ type: 'mute' })
  }
  async unmute(): Promise<void> {
    if (!this.node || this.failed) throw new Error('processor unavailable')
    this.cancelUnmute?.()
    const intent = ++this.intent
    await this.bounded(new Promise<void>((resolve, reject) => {
      const finish = (error?: Error) => { this.acknowledge = undefined; this.cancelUnmute = undefined; error ? reject(error) : resolve() }
      this.acknowledge = received => { if (received === intent) finish() }
      this.cancelUnmute = finish
      this.node!.port.postMessage({ type: 'unmute', intent })
    })).catch(error => { this.fail(); throw error })
  }
  async restart(opts: AudioProcessorOptions): Promise<void> { await this.destroy(); await this.init(opts) }
  async destroy(): Promise<void> {
    if (this.disposal) { this.generation++; return this.disposal }
    this.generation++; this.preparation?.abort(); this.preparation = undefined; this.mute(); this.cancelReady?.()
    this.source?.disconnect(); this.node?.disconnect(); this.destination?.disconnect()
    const node = this.node
    this.processedTrack?.stop()
    this.source = undefined; this.node = undefined; this.destination = undefined
    this.processedTrack = undefined; this.sourceTrack = undefined
    if (!node) return
    node.onprocessorerror = null
    const disposal = this.disposal = disposePort(node.port, Math.min(this.options.timeoutMs ?? 1000, 1000))
    try { await disposal } finally { if (this.disposal === disposal) this.disposal = undefined }
  }
}
