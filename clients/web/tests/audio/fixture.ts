import { RnnoiseTrackProcessor } from '../../src/voice/noise_suppression/rnnoise_track_processor'
import { loadRnnoiseAssets } from '../../src/voice/noise_suppression/rnnoise_loader'
import { SampleRingBuffer } from '../../src/voice/noise_suppression/ring_buffer'
import { Track } from 'livekit-client'
import { checkUnmuteRace } from './unmute_race_fixture'
interface MeterReading { samples: number; rms: number; peak: number; nonfinite: number }
const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))
function meter(context: AudioContext, track: MediaStreamTrack) {
  const readings: MeterReading[] = []
  const node = new AudioWorkletNode(context, 'rnnoise-test-meter'), source = context.createMediaStreamSource(new MediaStream([track]))
  source.connect(node); node.connect(context.destination)
  let onReset: (() => void) | undefined
  node.port.onmessage = event => { if (event.data === 'reset') onReset?.(); else readings.push(event.data) }
  return { readings, async reset() {
    await new Promise<void>(resolve => { onReset = resolve; node.port.postMessage('reset') })
    onReset = undefined; readings.length = 0
  }, stop() { source.disconnect(); node.disconnect(); node.port.close() } }
}
async function setup(rate = 48000) {
  const context = new AudioContext({ sampleRate: rate }); await context.resume()
  const oscillator = context.createOscillator(), gain = context.createGain(), destination = context.createMediaStreamDestination()
  oscillator.frequency.value = 440; gain.gain.value = 0.2
  oscillator.connect(gain); gain.connect(destination); oscillator.start()
  const track = destination.stream.getAudioTracks()[0]
  await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
  const states: unknown[] = [], failures: string[] = []
  const processor = new RnnoiseTrackProcessor({ onState: state => states.push(state), onFailure: reason => failures.push(reason) })
  return { context, oscillator, gain, track, processor, states, failures,
    async init() { await processor.init({ kind: Track.Kind.Audio, track, audioContext: context }) },
    async stop() { await processor.destroy(); oscillator.stop(); gain.disconnect(); destination.disconnect(); track.stop(); await context.close() } }
}
const gate = {
  async graph() {
    const test = await setup()
    try {
      await test.init(); await test.processor.unmute(); test.processor.processedTrack!.enabled = true
      const output = meter(test.context, test.processor.processedTrack!)
      await wait(1400)
      const active = output.readings.splice(0)
      test.processor.mute(); test.gain.gain.value = 0; await wait(200); output.readings.length = 0; await wait(300)
      const muted = output.readings.splice(0), mutedTrackDisabled = !test.processor.processedTrack!.enabled
      test.gain.gain.value = 0
      await output.reset()
      await test.processor.unmute(); test.processor.processedTrack!.enabled = true
      output.readings.length = 0; await wait(350)
      const afterUnmute = output.readings.splice(0)
      const fault = await gate.processorFault()
      output.stop()
      return { active, muted, mutedTrackDisabled, afterUnmute, fault, states: test.states, sampleRate: test.context.sampleRate }
    } finally { await test.stop() }
  },
  async processorFault() {
    const test = await setup()
    const failures: string[] = []
    const processor = new RnnoiseTrackProcessor({ workletUrl: '/tests/audio/fault.worklet.js', onFailure: reason => failures.push(reason) })
    try {
      await processor.init({ kind: Track.Kind.Audio, track: test.track, audioContext: test.context })
      await wait(100)
      return { disabled: !processor.processedTrack!.enabled, failures }
    } finally { await processor.destroy(); await test.stop() }
  },
  async invalidRate() {
    const test = await setup(44100)
    try { await test.init(); return { rejected: false } } catch { return { rejected: true, failures: test.failures, rate: test.context.sampleRate } }
    finally { await test.stop() }
  },
  async badAsset(path: string) {
    try { await loadRnnoiseAssets(path); return false } catch { return true }
  },
  async transitions() {
    const test = await setup()
    try {
      let graphs = 0
      for (let i = 0; i < 100; i++) {
        await test.init(); const output = test.processor.processedTrack!
        await test.processor.unmute(); output.enabled = true; test.processor.mute()
        await test.processor.destroy()
        if (output.readyState !== 'ended' || test.track.readyState !== 'live' || test.processor.processedTrack !== undefined) throw new Error('Ownership leak')
        graphs++
      }
      return { graphs, contextState: test.context.state, sourceState: test.track.readyState }
    } finally { await test.stop() }
  },
  async unmuteRace() {
    const test = await setup()
    try { await test.init(); return await checkUnmuteRace(test.processor) } finally { await test.stop() }
  },
  async rtcPair() {
    const test = await setup(), sender = new RTCPeerConnection(), receiver = new RTCPeerConnection()
    let receiveMeter: ReturnType<typeof meter> | undefined
    try {
      await test.init(); await test.processor.unmute(); test.processor.processedTrack!.enabled = true
      sender.onicecandidate = event => { if (event.candidate) void receiver.addIceCandidate(event.candidate) }
      receiver.onicecandidate = event => { if (event.candidate) void sender.addIceCandidate(event.candidate) }
      const element = document.createElement('audio'); element.autoplay = true; element.muted = true; document.body.append(element)
      const received = new Promise<void>(resolve => { receiver.ontrack = event => { element.srcObject = new MediaStream([event.track]); void element.play(); receiveMeter = meter(test.context, event.track); resolve() } })
      sender.addTrack(test.processor.processedTrack!)
      await sender.setLocalDescription(await sender.createOffer()); await receiver.setRemoteDescription(sender.localDescription!)
      await receiver.setLocalDescription(await receiver.createAnswer()); await sender.setRemoteDescription(receiver.localDescription!)
      await Promise.race([received, wait(10000).then(() => { throw new Error('Peer track timeout') })]); await wait(1400)
      const active = receiveMeter!.readings.splice(0)
      test.processor.mute(); await wait(300); await receiveMeter!.reset(); await wait(350)
      return { active, muted: receiveMeter!.readings, sender: sender.connectionState, receiver: receiver.connectionState,
        modelId: test.processor.runtimeState.modelId, path: 'direct-RTCPeerConnection-graph-only' }
    } finally { receiveMeter?.stop(); sender.close(); receiver.close(); await test.stop() }
  },
  variableQuantum() {
    const fifo = new SampleRingBuffer(480); let frames = 0, pending = 0
    for (const length of [64, 128, 240, 256, 480, 960, 128, 64]) for (let i = 0; i < length; i++) {
      fifo.push(i); pending++
      if (fifo.size === 480) { for (let j = 0; j < 480; j++) fifo.shift(); frames++ }
    }
    return { frames, residual: fifo.size, samples: pending }
  },
}
;(window as unknown as { audioGate: typeof gate }).audioGate = gate
