import { defaultAudioProcessing, microphoneConstraints } from './media_publishing'
import type { AudioProcessingOptions, NoiseSuppressionRuntimeState } from './noise_suppression/types'
import { prepareLocalMicrophoneProbe } from './local_microphone_probe'
export interface MicrophoneCheck {
  processingState?(): NoiseSuppressionRuntimeState
  level(): number
  onEnded(listener: () => void): () => void
  stop(): Promise<void>
}

export function levelFromSamples(samples: Uint8Array): number {
  if (!samples.length) return 0
  let energy = 0
  for (const value of samples) energy += ((value - 128) / 128) ** 2
  return Math.min(100, Math.round(Math.sqrt(energy / samples.length) * 100))
}

export interface MicrophoneCheckOptions {
  processing?: AudioProcessingOptions
  inCall?: boolean
  borrowedTrack?: MediaStreamTrack
}
export async function startMicrophoneCheck(
  deviceId: string,
  devices: Pick<MediaDevices, 'getUserMedia'> = navigator.mediaDevices,
  makeContext: () => AudioContext = () => new AudioContext({ sampleRate: 48_000 }),
  options: MicrophoneCheckOptions = {},
): Promise<MicrophoneCheck> {
  if (options.inCall && !options.borrowedTrack) throw new Error('Микрофон звонка выключен. Для проверки сначала включите микрофон.')
  const processing = options.processing ?? defaultAudioProcessing
  const borrowed = Boolean(options.borrowedTrack)
  const stream = options.borrowedTrack ? new MediaStream([options.borrowedTrack]) : await devices.getUserMedia({
    audio: { ...microphoneConstraints(processing), ...(deviceId && deviceId !== 'default' ? { deviceId: { exact: deviceId } } : {}) }, video: false,
  })
  const stopCapture = () => { if (!borrowed) stream.getTracks().forEach((track) => track.stop()) }
  let context: AudioContext
  try { context = makeContext() } catch (cause) { stopCapture(); throw cause }
  let probe: Awaited<ReturnType<typeof prepareLocalMicrophoneProbe>> | undefined
  let source: MediaStreamAudioSourceNode | undefined
  let analyser: AnalyserNode
  try {
    await context.resume?.()
    probe = borrowed || (processing.noiseSuppressionMode !== 'rnnoise' && processing.noiseSuppressionMode !== 'deepfilter')
      ? undefined : await prepareLocalMicrophoneProbe(stream, context, processing)
    source = context.createMediaStreamSource(probe?.stream ?? stream)
    analyser = context.createAnalyser()
    analyser.fftSize = 256
    source.connect(analyser)
  } catch (cause) {
    source?.disconnect()
    try { await probe?.destroy() } finally { stopCapture(); await context.close() }
    throw cause
  }
  const samples = new Uint8Array(analyser.fftSize)
  const tracks = [...new Set([...stream.getTracks(), ...(probe?.stream.getTracks() ?? [])])]
  const removers = new Set<() => void>()
  let stopped = false
  return {
    processingState: () => {
      if (probe) return probe.state()
      const reported = stream.getTracks()[0]?.getSettings?.().noiseSuppression
      return { requestedMode: processing.noiseSuppressionMode, effectiveMode: reported === undefined ? 'unknown' : reported ? 'browser' : 'off', status: reported === undefined ? 'idle' : 'active' }
    },
    level: () => {
      if (stopped) return 0
      analyser.getByteTimeDomainData(samples)
      return levelFromSamples(samples)
    },
    onEnded: (listener) => {
      const onTrackEnded = () => { if (!stopped) listener() }
      tracks.forEach((track) => track.addEventListener('ended', onTrackEnded))
      const remove = () => { tracks.forEach((track) => track.removeEventListener('ended', onTrackEnded)); removers.delete(remove) }
      removers.add(remove)
      return remove
    },
    stop: async () => {
      if (stopped) return
      stopped = true
      removers.forEach((remove) => remove())
      source?.disconnect()
      try { await probe?.destroy() } finally { stopCapture(); await context.close() }
    },
  }
}

export async function playSpeakerCheck(deviceId: string): Promise<void> {
  const context = new AudioContext()
  const destination = context.createMediaStreamDestination()
  const tone = context.createOscillator()
  const gain = context.createGain()
  const audio = new Audio()
  audio.srcObject = destination.stream
  tone.frequency.value = 440
  gain.gain.value = 0.12
  tone.connect(gain).connect(destination)
  let started = false
  try {
    if (deviceId && deviceId !== 'default') {
      if (!('setSinkId' in audio)) throw new Error('Этот браузер не умеет выбирать динамик для проверки звука.')
      await audio.setSinkId(deviceId)
    }
    await context.resume()
    tone.start()
    started = true
    await audio.play()
    await new Promise<void>((resolve) => setTimeout(resolve, 400))
  } finally {
    if (started) tone.stop()
    audio.pause()
    audio.srcObject = null
    await context.close()
  }
}
