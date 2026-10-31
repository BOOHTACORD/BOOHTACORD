import { bindLiveKitMicrophone } from './noise_suppression/microphone_adapter/factory'
import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import type { VoiceRoom } from './livekit_gateway'
import { adaptiveMediaRoomOptions } from './media_publishing'
import { bindScreenProfile } from './screen_profile/bind'
import { BoundedVoiceReconnectPolicy } from './bounded_voice_reconnect_policy'
import { clearLiveKitScreenDiagnostics, inspectLiveKitScreenDiagnostics, type LiveKitScreenVideoTrack } from './screen_livekit_diagnostics'
import { readVoiceConnectionStats } from './voice_connection_quality'
import { bindLiveKitScreenPreview } from './screen_preview/capture'
import { selectedVoiceAudioProfile } from './audio_profile/profile'
import { bindVoiceAudioDiagnostics } from './audio_diagnostics/bind'
import { bindNetworkDiagnostics } from './network_diagnostics/bind'
import { bindLiveKitScreenPublisher } from './screen_publisher/livekit_port'
import { screenPublisherEventHandlers } from './screen_publisher/events'
import { bindLiveKitScreenMetadata } from './screen_profile_metadata/livekit_binding'

export function wireLiveKitRoom(
  room: VoiceRoom,
  viewer: Pick<ReturnType<typeof bindLiveKitScreenViewer>, 'clear' | 'refresh' | 'subscribeMicrophones' | 'seedVoiceParticipantSounds' | 'resetVoiceParticipantSounds'>,
): VoiceRoom {
  const connect = room.connect.bind(room)
  const disconnect = room.disconnect.bind(room)
  room.connect = async (url, token, options) => {
    viewer.resetVoiceParticipantSounds()
    await connect(url, token, { ...options, autoSubscribe: false })
    viewer.seedVoiceParticipantSounds()
    viewer.subscribeMicrophones()
    viewer.refresh()
  }
  room.disconnect = async () => {
    viewer.resetVoiceParticipantSounds()
    await room.stopScreenPreview?.()
    await room.clearScreenProfileMetadata?.().catch(() => undefined)
    const microphoneCleanup = room.disposeMicrophone?.()
    viewer.clear()
    try { await disconnect() } finally { await microphoneCleanup }
  }
  return room
}

export async function defaultLiveKitRoomFactory(): Promise<VoiceRoom> {
  const sdk = await import('livekit-client')
  const { Room, RoomEvent, Track } = sdk
  const liveKitRoom = new Room({ ...adaptiveMediaRoomOptions, reconnectPolicy: new BoundedVoiceReconnectPolicy() })
  const viewer = bindLiveKitScreenViewer(liveKitRoom as unknown as LiveKitScreenViewerRoom, {
    activeSpeakersChanged: RoomEvent.ActiveSpeakersChanged,
    attributesChanged: RoomEvent.ParticipantAttributesChanged,
    localTrackPublished: RoomEvent.LocalTrackPublished,
    localTrackUnpublished: RoomEvent.LocalTrackUnpublished,
    participantConnected: RoomEvent.ParticipantConnected,
    participantDisconnected: RoomEvent.ParticipantDisconnected,
    reconnecting: RoomEvent.Reconnecting,
    signalReconnecting: RoomEvent.SignalReconnecting,
    reconnected: RoomEvent.Reconnected,
    disconnected: RoomEvent.Disconnected,
    trackPublished: RoomEvent.TrackPublished,
    trackMuted: RoomEvent.TrackMuted,
    trackSubscribed: RoomEvent.TrackSubscribed,
    trackSubscriptionFailed: RoomEvent.TrackSubscriptionFailed,
    trackUnmuted: RoomEvent.TrackUnmuted,
    trackUnpublished: RoomEvent.TrackUnpublished,
    trackUnsubscribed: RoomEvent.TrackUnsubscribed,
  }, {
    microphone: Track.Source.Microphone,
    screenAudio: Track.Source.ScreenShareAudio,
    screenVideo: Track.Source.ScreenShare,
  })
  const preview = bindLiveKitScreenPreview(
    liveKitRoom as unknown as Parameters<typeof bindLiveKitScreenPreview>[0],
    viewer,
    {
      trackPublished: RoomEvent.LocalTrackPublished,
      trackUnpublished: RoomEvent.LocalTrackUnpublished,
      disconnected: RoomEvent.Disconnected,
    },
    Track.Source.ScreenShare,
  )
  let diagnosticsTrack: LiveKitScreenVideoTrack | undefined
  liveKitRoom.on(RoomEvent.LocalTrackUnpublished, (publication) => {
    if (publication.source !== Track.Source.ScreenShare) return
    const unpublished = publication.videoTrack as LiveKitScreenVideoTrack | undefined
    if (unpublished ?? diagnosticsTrack) clearLiveKitScreenDiagnostics(unpublished ?? diagnosticsTrack!)
    diagnosticsTrack = undefined
  })
  liveKitRoom.on(RoomEvent.Disconnected, () => {
    if (diagnosticsTrack) clearLiveKitScreenDiagnostics(diagnosticsTrack)
    diagnosticsTrack = undefined
  })
  const room = wireLiveKitRoom(liveKitRoom as unknown as VoiceRoom, viewer)
  room.stopScreenPreview = preview.stop
  room.applyScreenPreview = preview.apply
  room.clearScreenPreview = preview.clear
  room.screenViewer = viewer.viewer
  room.participantCards = viewer.participants
  room.remoteVoices = viewer.remoteVoices
  room.setDeafened = viewer.setDeafened
  const audioProfile = selectedVoiceAudioProfile()
  bindLiveKitMicrophone(room, liveKitRoom, sdk, audioProfile)
  bindVoiceAudioDiagnostics(room, liveKitRoom, audioProfile); bindNetworkDiagnostics(room, liveKitRoom)
  room.readScreenDiagnostics = async () => {
    const video = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack as LiveKitScreenVideoTrack | undefined
    diagnosticsTrack = video
    const audio = liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShareAudio)?.audioTrack
    return inspectLiveKitScreenDiagnostics(video, Boolean(audio), liveKitRoom.localParticipant.connectionQuality)
  }
  room.readVoiceConnectionStats = async () => {
    const manager = liveKitRoom.engine.pcManager
    const reports = await Promise.all([manager?.publisher.getStats(), manager?.subscriber?.getStats()])
    const samples = reports.map((report) => readVoiceConnectionStats(liveKitRoom.localParticipant.connectionQuality, report?.values()))
    return samples.find((sample) => sample.pingMs !== null) ?? samples[0]!
  }
  const profileGuard = bindScreenProfile(room, () => liveKitRoom.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack)
  const screenPublisher = bindLiveKitScreenPublisher(liveKitRoom.localParticipant, () => room.readScreenDiagnostics!(),
    profile => room.adoptScreenProfile?.(profile), (profile, action, current) => profileGuard.repair(profile, action, current))
  const metadata = bindLiveKitScreenMetadata(liveKitRoom, Track.Source.ScreenShare, () => screenPublisher.generation())
  room.screenPublisher = screenPublisher
  room.bindScreenPreviewLease = async leaseId => {
    await metadata.bindLease(leaseId)
    await preview.bindLease(leaseId)
  }
  room.publishScreenProfileMetadata = metadata.publish
  room.clearScreenProfileMetadata = metadata.clear
  liveKitRoom.on(RoomEvent.Reconnected, metadata.reconnected)
  const screenPublisherEvents = screenPublisherEventHandlers(screenPublisher, Track.Source.ScreenShare, profileGuard)
  liveKitRoom.on(RoomEvent.LocalTrackPublished, screenPublisherEvents.published); liveKitRoom.on(RoomEvent.LocalTrackUnpublished, screenPublisherEvents.unpublished)
  liveKitRoom.on(RoomEvent.Reconnecting, screenPublisherEvents.reconnecting); liveKitRoom.on(RoomEvent.SignalReconnecting, screenPublisherEvents.reconnecting)
  liveKitRoom.on(RoomEvent.Reconnected, screenPublisherEvents.reconnected); liveKitRoom.on(RoomEvent.Disconnected, screenPublisherEvents.disconnected)
  return room
}
