import { LocalAudioTrack, Room, RoomEvent, Track } from 'livekit-client'
import { RnnoiseTrackProcessor } from '../../src/voice/noise_suppression/rnnoise_track_processor'
import { DeepFilterTrackProcessor } from '../../src/voice/noise_suppression/deepfilter/track_processor'
interface MeterReading { samples: number; rms: number; peak: number; nonfinite: number }
let activeRoom: Room | undefined
let context: AudioContext | undefined
let localTrack: LocalAudioTrack | undefined
let processor: RnnoiseTrackProcessor | DeepFilterTrackProcessor | undefined
let oscillator: OscillatorNode | undefined
let meter: AudioWorkletNode | undefined
let meterSource: MediaStreamAudioSourceNode | undefined
let remoteElement: HTMLMediaElement | undefined
const readings: MeterReading[] = []
let resetAcknowledged: (() => void) | undefined
async function connect(role: 'sender' | 'receiver') {
  const credentials = await (await fetch(`/tests/audio/livekit-token?role=${role}`, { cache: 'no-store' })).json()
  const room = new Room()
  activeRoom = room
  context = new AudioContext({ sampleRate: 48000 }); await context.resume()
  await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
  if (role === 'receiver') room.on(RoomEvent.TrackSubscribed, track => {
    if (track.kind !== Track.Kind.Audio) return
    // Chromium requires remote playout attachment, even for aggregate meter use.
    remoteElement = track.attach(); remoteElement.muted = true; document.body.append(remoteElement); void remoteElement.play()
    meterSource = context!.createMediaStreamSource(new MediaStream([track.mediaStreamTrack]))
    meter = new AudioWorkletNode(context!, 'rnnoise-test-meter')
    meterSource.connect(meter); meter.connect(context!.destination)
    meter.port.onmessage = event => { if (event.data === 'reset') resetAcknowledged?.(); else readings.push(event.data) }
  })
  await room.connect(credentials.url, credentials.token)
  return room
}
export const livekitPairFixture = {
  async receiver() { await connect('receiver'); return true },
  async sender(engine: 'rnnoise' | 'deepfilter-research' = 'rnnoise') {
    const room = await connect('sender')
    oscillator = context!.createOscillator(); oscillator.frequency.value = 440
    const gain = context!.createGain(); gain.gain.value = 0.2
    const destination = context!.createMediaStreamDestination()
    oscillator.connect(gain); gain.connect(destination); oscillator.start()
    localTrack = new LocalAudioTrack(destination.stream.getAudioTracks()[0], { sampleRate: 48000 }, true, context!)
    processor = engine === 'rnnoise' ? new RnnoiseTrackProcessor() : new DeepFilterTrackProcessor()
    await localTrack.setProcessor(processor)
    await processor.unmute(); processor.processedTrack!.enabled = true
    await room.localParticipant.publishTrack(localTrack, { source: Track.Source.Microphone, audioPreset: { maxBitrate: 128000, priority: 'high' }, forceStereo: false })
    return processor instanceof RnnoiseTrackProcessor
      ? { engine: processor.runtimeState.effectiveMode, modelId: processor.runtimeState.modelId, sampleRate: context!.sampleRate }
      : { engine, sampleRate: context!.sampleRate }
  },
  async mute() { processor?.mute(); await localTrack?.mute(); return true },
  read() { return { readings: readings.splice(0), state: activeRoom?.state } },
  async resetMeter() {
    if (!meter) throw new Error('Receiver meter is not ready')
    await new Promise<void>(resolve => { resetAcknowledged = resolve; meter!.port.postMessage('reset') })
    resetAcknowledged = undefined; readings.length = 0
  },
  async stop() {
    meterSource?.disconnect(); meter?.disconnect(); meter?.port.close()
    remoteElement?.remove(); await activeRoom?.disconnect()
    await processor?.destroy(); localTrack?.stop(); oscillator?.stop(); await context?.close()
    activeRoom = undefined; processor = undefined; localTrack = undefined; context = undefined
    readings.length = 0
  },
}
;(window as unknown as { livekitAudioGate: typeof livekitPairFixture }).livekitAudioGate = livekitPairFixture
