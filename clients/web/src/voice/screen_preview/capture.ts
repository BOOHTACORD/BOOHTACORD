import { accountIdFromMetadata } from '../participant_identity'
import { captureLocalScreenThumbnails, type LocalScreenThumbnailTrack } from '../screen_thumbnail'
import { LatestScreenPreviewUploader } from './uploader'

interface PreviewPublication {
  source: string
  videoTrack?: LocalScreenThumbnailTrack
}
interface PreviewParticipant {
  identity: string
  metadata: string
  getTrackPublication(source: string): PreviewPublication | undefined
}
interface PreviewRoom {
  on(event: unknown, handler: (publication?: PreviewPublication) => void): unknown
  localParticipant: PreviewParticipant
  remoteParticipants: Map<string, PreviewParticipant>
}
interface PreviewViewer {
  viewer: {
    setThumbnail(participantId: string, bytes: Uint8Array): void
    removeThumbnail(participantId: string): void
  }
}
interface PreviewEvents {
  trackPublished: unknown
  trackUnpublished: unknown
  disconnected: unknown
}

export function bindLiveKitScreenPreview(
  room: PreviewRoom,
  viewer: PreviewViewer,
  events: PreviewEvents,
  screenSource: string,
) {
  const uploader = new LatestScreenPreviewUploader()
  let leaseId: string | null = null
  let stopCapture: (() => void) | null = null
  let cleanup: Promise<void> | null = null
  const localId = () => accountIdFromMetadata(room.localParticipant.metadata) ?? room.localParticipant.identity
  const stop = (): Promise<void> => {
    stopCapture?.()
    stopCapture = null
    if (cleanup) return cleanup
    const operation = uploader.stop()
    let shared!: Promise<void>
    shared = operation.finally(() => { if (cleanup === shared) cleanup = null })
    cleanup = shared
    return shared
  }
  const start = async (track: LocalScreenThumbnailTrack, participantId: string) => {
    stopCapture?.()
    stopCapture = null
    const requestedLease = leaseId
    await cleanup
    if (requestedLease !== leaseId) return
    stopCapture = captureLocalScreenThumbnails(track, (bytes) => {
      viewer.viewer.setThumbnail(participantId, bytes)
    })
    if (requestedLease) void uploader.start(requestedLease).catch(() => undefined)
  }
  room.on(events.trackPublished, (publication) => {
    if (publication?.source !== screenSource || !publication.videoTrack) return
    void start(publication.videoTrack, localId())
  })
  room.on(events.trackUnpublished, (publication) => {
    if (publication?.source !== screenSource) return
    void stop()
    viewer.viewer.removeThumbnail(localId())
  })
  room.on(events.disconnected, () => { void stop() })
  return {
    async bindLease(value: string) {
      if (leaseId !== value) {
        leaseId = null
        await stop()
        leaseId = value
      }
      const publication = room.localParticipant.getTrackPublication(screenSource)
      if (publication?.videoTrack) await start(publication.videoTrack, localId()).catch(() => undefined)
    },
    stop,
    apply(lease: string, bytes: Uint8Array) {
      const participant = room.remoteParticipants.get(`voice-lease:${lease}`)
      if (!participant?.getTrackPublication(screenSource)) return
      viewer.viewer.setThumbnail(accountIdFromMetadata(participant.metadata) ?? participant.identity, bytes)
    },
    clear(lease: string) {
      const participant = room.remoteParticipants.get(`voice-lease:${lease}`)
      if (participant) viewer.viewer.removeThumbnail(accountIdFromMetadata(participant.metadata) ?? participant.identity)
    },
  }
}
