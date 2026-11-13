import { createApp, defineComponent, h, ref, shallowRef, type App } from 'vue'
import { createPinia } from 'pinia'
import { Room, RoomEvent, Track } from 'livekit-client'
import AudioSettings from '../../src/voice/AudioSettings.vue'
import { useAudioSettingsStore } from '../../src/voice/audio_settings_store'
import { VoiceSession } from '../../src/voice/voice_session'
import { connectLiveKitRoom, type VoiceJoinMode } from '../../src/voice/livekit_gateway'
import { defaultLiveKitRoomFactory } from '../../src/voice/livekit_room_factory'
import { installSyntheticInputs } from './synthetic_inputs'
import type { NoiseSuppressionMode } from '../../src/voice/noise_suppression/types'

let app: App | undefined
let session: VoiceSession | undefined
let input: ReturnType<typeof installSyntheticInputs> | undefined
let receiver: Room | undefined
let receiveContext: AudioContext | undefined
let analyser: AnalyserNode | undefined
let playback: HTMLMediaElement | undefined
let stopInputListener: (() => void) | undefined
let store: ReturnType<typeof useAudioSettingsStore> | undefined
let refresh: (() => void) | undefined
const connected = ref(false)
const microphoneTrack = shallowRef<MediaStreamTrack>()

const gate = {
  async mount(mode: NoiseSuppressionMode = 'off') {
    input = installSyntheticInputs()
    session = new VoiceSession({
      acquire: async channelId => ({ id: 'qa-lease', channelId, transferred: false }),
      credential: async () => (await fetch('/tests/audio/livekit-token?role=sender')).json(),
      release: async () => undefined,
    }, (credential, processing, joinMode, inputId) => connectLiveKitRoom(credential, defaultLiveKitRoomFactory, processing, undefined, joinMode, inputId))
    const root = document.createElement('div'); document.body.append(root)
    app = createApp(defineComponent({ setup() {
      store = useAudioSettingsStore()
      const apply = async (id: string) => (await session!.switchAudioDevice('audioinput', id))!
      const load = async () => { await store!.loadInput(apply); await store!.load(); await store!.reconcileInput(apply) }
      refresh = () => { void load() }
      navigator.mediaDevices.addEventListener('devicechange', refresh)
      return () => h(AudioSettings, {
        activationError: null, activationMode: 'VAD', processingDiagnostics: session!.audioProcessing.diagnostics,
        devices: store!.devices, error: store!.error, processing: store!.processing, state: store!.state,
        pttKey: null, connected: connected.value, microphoneTrack: microphoneTrack.value,
        inputDeviceId: store!.selectedInput, inputWarning: store!.inputWarning, inputSwitching: store!.inputSwitching,
        onLoad: load, onSelect: (kind, id) => { if (kind === 'audioinput') void store!.selectInput(id, apply) },
      })
    } })).use(createPinia())
    app.mount(root)
    await session.setAudioProcessing({ autoGainControl: false, echoCancellation: false, noiseSuppressionMode: mode })
  },
  async join(joinMode: VoiceJoinMode = 'with-microphone') {
    await store!.loadInput(async id => (await session!.switchAudioDevice('audioinput', id))!)
    await session!.join('qa-room', true, joinMode)
    connected.value = true
    microphoneTrack.value = session!.active!.room.readMicrophoneTrack?.()
    store!.observeInput(session!.inputSelection)
    stopInputListener = session!.active!.room.onAudioInputSelection?.(selection => {
      store!.observeInput(selection)
      microphoneTrack.value = session!.active?.room.readMicrophoneTrack?.()
    })
    return this.read()
  },
  async mute(muted = true) { await session!.setMicrophoneMuted(muted); microphoneTrack.value = session!.active?.room.readMicrophoneTrack?.(); return this.read() },
  async deafen(enabled: boolean) { await session!.setDeafened(enabled); return this.read() },
  async reconnect() { await (session!.active!.room as unknown as Room).simulateScenario('resume-reconnect') },
  ignoreNextConstraint() { input!.ignoreNextConstraint() },
  unplug(id: string) { input!.unplug(id) },
  removeAll() { input!.removeAll() },
  read() {
    return { selected: store?.selectedInput, selection: session?.inputSelection, warning: store?.inputWarning,
      microphone: session?.active?.microphone, enabled: session?.active?.room.readMicrophoneTrack?.()?.enabled,
      processing: session?.active?.room.readNoiseSuppressionState?.(),
      ownedCapture: (session?.active?.room as unknown as Room | undefined)?.localParticipant.getTrackPublication(Track.Source.Microphone)?.audioTrack?.isUserProvided,
      captures: input?.captures.map(({ deviceId, track }) => ({ deviceId, ended: track.readyState === 'ended' })),
    }
  },
  async receiver() {
    const credential = await (await fetch('/tests/audio/livekit-token?role=receiver')).json()
    receiveContext = new AudioContext({ sampleRate: 48000 }); await receiveContext.resume()
    receiver = new Room()
    receiver.on(RoomEvent.TrackSubscribed, track => {
      if (track.kind !== Track.Kind.Audio) return
      playback = track.attach(); playback.muted = true; document.body.append(playback); void playback.play()
      analyser = receiveContext!.createAnalyser(); analyser.fftSize = 4096; analyser.smoothingTimeConstant = 0
      const source = receiveContext!.createMediaStreamSource(new MediaStream([track.mediaStreamTrack]))
      source.connect(analyser)
    })
    await receiver.connect(credential.url, credential.token)
  },
  sample() {
    if (!analyser) return { rms: 0, frequency: 0, nonfinite: 0 }
    const pcm = new Float32Array(analyser.fftSize), spectrum = new Float32Array(analyser.frequencyBinCount)
    analyser.getFloatTimeDomainData(pcm); analyser.getFloatFrequencyData(spectrum)
    const rms = Math.sqrt(pcm.reduce((sum, value) => sum + value * value, 0) / pcm.length)
    let peak = 0
    for (let i = 1; i < spectrum.length; i++) if (spectrum[i] > spectrum[peak]) peak = i
    return { rms, frequency: rms > 0.001 ? peak * receiveContext!.sampleRate / analyser.fftSize : 0, nonfinite: pcm.filter(value => !Number.isFinite(value)).length }
  },
  async stop() {
    stopInputListener?.(); stopInputListener = undefined
    if (refresh) navigator.mediaDevices.removeEventListener('devicechange', refresh)
    app?.unmount(); app = undefined
    await session?.leave(); session = undefined
    input?.dispose(); input = undefined
    connected.value = false; microphoneTrack.value = undefined
    await receiver?.disconnect(); receiver = undefined
    playback?.remove(); await receiveContext?.close()
    receiveContext = undefined; analyser = undefined
  },
}
;(window as unknown as { audioInputGate: typeof gate }).audioInputGate = gate
