import { LiveKitScreenRegistry, type ScreenParticipantPublication } from './livekit_screen_registry'
import { bindLiveKitRemoteParticipants, type LiveKitRemoteParticipant } from './livekit_remote_participants'
import { accountIdFromMetadata } from './participant_identity'
import { RemoteVoicePlayback } from './remote_voice_playback'
import { ScreenViewerController, type ScreenViewerPublication } from './screen_viewer_controller'
import { bindLiveKitScreenViewerPresence } from './screen_viewer_presence'
import { bindLiveKitRemoteVoiceEvents } from './livekit_remote_voice_events'
import { replaceScreenPreviewParticipantLeases } from './screen_preview/participant_leases'

export interface LiveKitScreenViewerRoom {
  name?: string
  localParticipant?: LiveKitRemoteParticipant
  on(event: unknown, listener: (...arguments_: any[]) => void): unknown
  remoteParticipants: Map<string, LiveKitRemoteParticipant>
}

export interface LiveKitScreenViewerEvents {
  attributesChanged?: unknown
  activeSpeakersChanged: unknown
  localTrackPublished: unknown
  localTrackUnpublished: unknown
  participantConnected: unknown
  participantDisconnected: unknown
  trackMuted: unknown
  trackPublished: unknown
  trackSubscribed: unknown
  trackSubscriptionFailed?: unknown
  trackUnmuted: unknown
  trackUnpublished: unknown
  trackUnsubscribed: unknown
}

export interface LiveKitScreenSources {
  microphone: unknown
  screenAudio: unknown
  screenVideo: unknown
}

export interface LiveKitScreenViewerBinding {
  clear(): void
  refresh(): void
  participants: ReturnType<typeof bindLiveKitRemoteParticipants>
  remoteVoices: RemoteVoicePlaybackController
  setDeafened(deafened: boolean): void
  subscribeMicrophones(): void
  viewer: ScreenViewerController
}

export type RemoteVoicePlaybackController = Pick<RemoteVoicePlayback, 'attach' | 'cards' | 'clear' | 'detach' | 'forget' | 'isSpeaking' | 'onChange' | 'setDeafened' | 'setSpeaking' | 'setVolume'>

export function bindLiveKitScreenViewer(
  room: LiveKitScreenViewerRoom,
  events: LiveKitScreenViewerEvents,
  sources: LiveKitScreenSources,
  voicePlayback: RemoteVoicePlaybackController = new RemoteVoicePlayback(),
): LiveKitScreenViewerBinding {
  const registry = new LiveKitScreenRegistry(typeof window === 'undefined' ? '' : window.location.origin, room.name ?? '')
  const viewer = new ScreenViewerController(() => registry.streams())
  const presence = bindLiveKitScreenViewerPresence(room, {
    localTrackPublished: events.localTrackPublished,
    localTrackUnpublished: events.localTrackUnpublished,
    participantDisconnected: events.participantDisconnected,
    trackSubscribed: events.trackSubscribed,
    trackUnsubscribed: events.trackUnsubscribed,
  }, sources.screenVideo, (watchers) => viewer.setWatchers(watchers))
  viewer.setWatcherRefresh(presence.refreshOwner)
  void presence.refreshOwner()
  const accountId = (participant: LiveKitRemoteParticipant) => accountIdFromMetadata(participant.metadata)
  const participantId = (participant: LiveKitRemoteParticipant) => accountId(participant) ?? participant.identity
  const participantCards = bindLiveKitRemoteParticipants(() => room.remoteParticipants.values(), sources.microphone, participantId, accountId, voicePlayback)
  const participants = (): ScreenParticipantPublication[] => {
    const remote = [...room.remoteParticipants.values()].map((participant) => ({
      accountId: accountId(participant) ?? undefined,
      attributes: participant.attributes,
      audio: participant.getTrackPublication(sources.screenAudio),
      identity: participantId(participant),
      name: participant.name,
      previewLeaseId: participant.identity.startsWith('voice-lease:') ? participant.identity.slice('voice-lease:'.length) : undefined,
      video: participant.getTrackPublication(sources.screenVideo),
    }))
    const local = room.localParticipant
    const localVideo = local?.getTrackPublication(sources.screenVideo)
    return [...remote, ...(local && localVideo ? [{
      accountId: accountId(local) ?? undefined,
      attributes: local.attributes,
      identity: participantId(local),
      isLocal: true,
      name: 'Ваш экран',
      video: localVideo,
    }] : [])]
  }
  const refresh = () => {
    const publications = participants()
    replaceScreenPreviewParticipantLeases(publications.flatMap((participant) => !participant.isLocal && participant.previewLeaseId
      ? [[participant.identity, participant.previewLeaseId] as const]
      : []))
    registry.refresh(publications, viewer.selectedId)
    participantCards.refresh()
    viewer.reconcile()
  }
  room.on(events.localTrackPublished, refresh)
  room.on(events.localTrackUnpublished, refresh)
  if (events.attributesChanged) room.on(events.attributesChanged, refresh)
  const subscribeMicrophones = () => room.remoteParticipants.forEach((participant) => participant.getTrackPublication(sources.microphone)?.setSubscribed?.(true))
  room.on(events.participantConnected, () => { refresh(); void presence.refreshOwner() })
  room.on(events.participantDisconnected, (participant: LiveKitRemoteParticipant) => {
    voicePlayback.forget(participantId(participant))
    viewer.removeThumbnail(participantId(participant))
    refresh()
    void presence.refreshOwner()
  })
  room.on(events.trackUnpublished, (publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.screenVideo) {
      viewer.removeThumbnail(participantId(participant))
    }
    refresh()
  })
  room.on(events.trackSubscribed, (_track: unknown, publication: ScreenViewerPublication & { source?: unknown }, participant: LiveKitRemoteParticipant) => {
    if (publication.source === sources.screenVideo && publication.trackSid) viewer.markSubscriptionSucceeded(publication.trackSid, participantId(participant))
  })
  if (events.trackSubscriptionFailed) room.on(events.trackSubscriptionFailed, (trackSid: string, participant: LiveKitRemoteParticipant) => {
    viewer.markSubscriptionFailed(trackSid, participantId(participant))
  })
  bindLiveKitRemoteVoiceEvents(room, events, sources, voicePlayback, participantId, accountId, refresh)
  return {
    clear: () => { replaceScreenPreviewParticipantLeases([]); voicePlayback.clear(); presence.clear(); viewer.clear() },
    refresh,
    participants: participantCards,
    remoteVoices: voicePlayback,
    setDeafened: (deafened) => { voicePlayback.setDeafened(deafened); viewer.setDeafened(deafened) },
    subscribeMicrophones,
    viewer,
  }
}
