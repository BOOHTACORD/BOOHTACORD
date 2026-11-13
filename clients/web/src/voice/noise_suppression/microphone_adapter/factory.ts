import type { Room } from 'livekit-client'
import type { VoiceRoom } from '../../livekit_gateway'
import { publishOptions, selectedVoiceAudioProfile, type VoiceAudioProfile } from '../../audio_profile/profile'
import { LiveKitMicrophoneAdapter } from './controller'
import { MicrophoneControlsProcessor } from '../../microphone_processing/processor'
import { RnnoiseTrackProcessor } from '../rnnoise_track_processor'
import { DeepFilterTrackProcessor } from '../deepfilter/track_processor'
export function bindLiveKitMicrophone(room: VoiceRoom, liveKitRoom: Room, sdk: typeof import('livekit-client'), profile: VoiceAudioProfile = selectedVoiceAudioProfile()): void {
  const { RoomEvent, Track, LocalAudioTrack, ConnectionState } = sdk
  // Retain the SDK-owned context for processing before first publication.
  let captureContext: AudioContext | undefined
  const setAudioContext = liveKitRoom.localParticipant.setAudioContext.bind(liveKitRoom.localParticipant)
  liveKitRoom.localParticipant.setAudioContext = (context) => {
    captureContext = context
    setAudioContext(context)
  }
  const microphone = new LiveKitMicrophoneAdapter({
    createTrack: async (options) => {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: options, video: false })
      const tracks = stream.getTracks()
      const audio = stream.getAudioTracks()[0]
      if (!audio || tracks.length !== 1) {
        tracks.forEach((track) => track.stop())
        throw new Error('Микрофон не предоставил аудиодорожку.')
      }
      // The adapter owns capture/recovery. A user-provided SDK track prevents
      // Room devicechange/track-ended handlers from independently restarting it.
      return new LocalAudioTrack(audio, options, true, captureContext)
    },
    publishTrack: (track, options) => liveKitRoom.localParticipant.publishTrack(track, { ...options, ...publishOptions(profile), source: Track.Source.Microphone }),
    unpublishTrack: (track) => liveKitRoom.localParticipant.unpublishTrack(track, false),
    isReconnecting: () => liveKitRoom.state === ConnectionState.Reconnecting || liveKitRoom.state === ConnectionState.SignalReconnecting,
    createProcessor: (callbacks, options) => new MicrophoneControlsProcessor(options?.autoGainControl ?? true,
      options?.noiseSuppressionMode === 'deepfilter'
        ? new DeepFilterTrackProcessor({ onFailure: reason => callbacks.onFailure(reason) })
        : new RnnoiseTrackProcessor(callbacks), () => callbacks.onFailure('processor-error')),
    createControlsProcessor: (options, failure) => new MicrophoneControlsProcessor(options.autoGainControl, undefined, failure),
  })
  room.setMicrophone = (enabled, options) => microphone.setEnabled(enabled, options)
  room.disposeMicrophone = () => microphone.dispose()
  room.applyMicrophoneProcessing = (options) => microphone.setProcessing(options)
  room.readAudioProcessingSettings = () => microphone.readCaptureSettings()
  room.readMicrophoneTrack = () => microphone.readOutputTrack()
  room.readAudioInputSelection = () => microphone.inputSelection
  room.onAudioInputSelection = (listener) => microphone.subscribeInput(listener)
  liveKitRoom.on(RoomEvent.Reconnecting, () => microphone.prepareReconnect())
  liveKitRoom.on(RoomEvent.Reconnected, () => { void microphone.reapplyDevice().catch(() => undefined) })
  room.readNoiseSuppressionState = () => microphone.runtimeState
  room.onNoiseSuppressionState = (listener) => microphone.subscribe(listener)
  const switchDevice = liveKitRoom.switchActiveDevice.bind(liveKitRoom)
  room.switchActiveDevice = (kind, deviceId) => kind === 'audioinput' ? microphone.switchDevice(deviceId) : switchDevice(kind, deviceId)
  liveKitRoom.on(RoomEvent.Disconnected, () => { void microphone.dispose().catch(() => undefined) })
}
