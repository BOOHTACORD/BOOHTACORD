import { createApp, h, ref } from 'vue'
import { LocalVideoTrack, LogLevel, Room, RoomEvent, Track, TrackEvent, RemoteTrackPublication, setLogLevel } from 'livekit-client'
import { TrackInfo, TrackSource, TrackType } from '@livekit/protocol'
import { LiveKitScreenRegistry } from '../../src/voice/livekit_screen_registry'
import { ScreenViewerController } from '../../src/voice/screen_viewer_controller'
import ScreenReceiverDiagnosticsPanel from '../../src/voice/ScreenReceiverDiagnosticsPanel.vue'
import '../../src/style.css'

setLogLevel(LogLevel.silent)
const room = new Room({ adaptiveStream: false, dynacast: false })
const registry = new LiveKitScreenRegistry()
const controller = new ScreenViewerController(() => registry.streams())
const version = ref(0)
const video = document.createElement('video'); video.className = 'screen-player'; video.autoplay = true; video.muted = true; video.style.cssText = 'width:min(700px,100%);height:360px;background:#050608;object-fit:contain'
let local: LocalVideoTrack | null = null
let frameTimer: number | null = null
let subscriptions = 0, unsubscriptions = 0
const observed = new WeakSet<RemoteTrackPublication>()
function refresh() {
  const participants = [...room.remoteParticipants.values()].flatMap(p => {
    const publication = p.getTrackPublication(Track.Source.ScreenShare)
    if (!publication) return []
    if (!observed.has(publication)) {
      observed.add(publication)
      publication.on(TrackEvent.UpdateSubscription, update => { if (update.subscribe) subscriptions++; else unsubscriptions++ })
    }
    return [{ identity: p.identity, name: p.name, attributes: p.attributes, video: publication }]
  })
  registry.refresh(participants, controller.selectedId)
  controller.reconcile(); version.value++
}
for (const event of [RoomEvent.TrackPublished, RoomEvent.TrackUnpublished, RoomEvent.ParticipantConnected, RoomEvent.ParticipantDisconnected, RoomEvent.TrackSubscribed, RoomEvent.TrackUnsubscribed, RoomEvent.Reconnected]) room.on(event, refresh)
createApp({ render: () => {
  void version.value
  const card = controller.cards()[0]
  return h('section', { style: 'padding:24px;max-width:900px;margin:auto' }, [
    h('h1', 'QA327 — реальный SDK/SFU'),
    h('p', 'Синтетический источник; профиль запуска не является измеренным FPS.'),
    card ? h('button', { onClick: () => { controller.select(card.id, video, null); version.value++ } }, 'Выбрать источник') : h('p', 'Источник не опубликован'),
    h('div', { id: 'video-slot', style: 'margin-top:16px' }),
    card ? h(ScreenReceiverDiagnosticsPanel, { actualVideoQuality: 'Нет измерений качества', hasAudio: false, isLocal: false, metrics: null, sampledAt: null, targetProfile: card.targetProfile, profileSource: card.profileSource, participantName: 'Синтетический источник' }) : null,
  ])
} }).mount('#app')
// Keep the same real media element across metadata/selection refreshes.
document.querySelector('#video-slot')!.append(video)
const qa = {
  protocolFixture(trackName: string) {
    const publication = new RemoteTrackPublication(Track.Kind.Video, new TrackInfo({ sid:'TR_protocol', name:trackName, type:TrackType.VIDEO, source:TrackSource.SCREEN_SHARE }), false)
    registry.refresh([{ identity:'synthetic-protocol-peer', video:publication }],null); version.value++
  },
  async connect(url: string, credential: string) { await room.connect(url, credential, { autoSubscribe: false }); refresh() },
  async publish(name: string) {
    const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 360
    const ctx = canvas.getContext('2d')!; let frames = 0
    const paint = () => { ctx.fillStyle = '#182438'; ctx.fillRect(0,0,640,360); ctx.fillStyle = '#ffffff'; ctx.font = '28px sans-serif'; ctx.fillText('QA327 synthetic source',35,85); ctx.fillText(String(++frames),35,150) }
    paint(); frameTimer = window.setInterval(paint, 67)
    local = new LocalVideoTrack(canvas.captureStream(15).getVideoTracks()[0]!)
    await room.localParticipant.publishTrack(local, { name, source: Track.Source.ScreenShare, simulcast: false, videoCodec: 'vp8', screenShareEncoding: { maxFramerate: 15, maxBitrate: 1_000_000 } })
  },
  async unpublish() { if (local) { await room.localParticipant.unpublishTrack(local,true); local.stop(); local=null }; if (frameTimer !== null) clearInterval(frameTimer); frameTimer=null },
  snapshot() {
    const streams=registry.streams(), publication=streams[0]?.video, active=video.srcObject instanceof MediaStream ? video.srcObject.getVideoTracks().filter(t=>t.readyState==='live').length : 0
    return { streams: streams.length, target: streams[0]?.targetProfile ?? null, provenance: streams[0]?.profileSource ?? 'unknown', descriptor_present: Boolean(streams[0]?.descriptor), SDK_trackName_present: Boolean(publication?.trackName), legacy_name_present: Boolean(publication && 'name' in publication), desired: publication?.isDesired ?? false, subscriptions, unsubscriptions, active_video_outputs: active, decoded_frames: video.getVideoPlaybackQuality().totalVideoFrames, width: video.videoWidth, height: video.videoHeight, actual_room_connected: room.state === 'connected' }
  },
  unselect() { controller.select(null,video,null); version.value++ },
  async reconnect(url: string, credential: string) { controller.clear(); await room.disconnect(); await room.connect(url,credential,{autoSubscribe:false}); refresh() },
  async stop() { await qa.unpublish(); controller.stop(); await room.disconnect(true); room.removeAllListeners() },
}
;(window as Window & { qa327?: typeof qa }).qa327 = qa
