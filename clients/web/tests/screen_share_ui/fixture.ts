import { createApp, defineComponent, h, reactive, ref } from 'vue'
import { createPinia } from 'pinia'
import ScreenShareSetupDialog from '../../src/voice/ScreenShareSetupDialog.vue'
import ScreenDiagnosticsPanel from '../../src/voice/ScreenDiagnosticsPanel.vue'
import ScreenReceiverDiagnosticsPanel from '../../src/voice/ScreenReceiverDiagnosticsPanel.vue'
import DiagnosisPanel from '../../src/voice/viewer_diagnosis/Panel.vue'
import ScreenViewer from '../../src/voice/ScreenViewer.vue'
import type { ScreenViewerCard } from '../../src/voice/screen_viewer_controller'
import type { VoiceVolumeParticipant } from '../../src/voice/voice_volume_controls'
import type { ScreenDiagnostics } from '../../src/voice/screen_diagnostics'
import { useScreenReceiverDiagnostics } from '../../src/voice/use_screen_receiver_diagnostics'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import '../../src/style.css'
const params = new URLSearchParams(location.search)
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
if (params.has('unsupported')) Object.defineProperty(navigator, 'mediaDevices', { value: {}, configurable: true })
const events: unknown[] = []
const state = reactive({ open: true, profile: params.get('profile') ?? 'P1080_60', source: 'ACTIVE', fps: 1, sampledAt: null as number | null, hasAudio: false, audioMuted: false })
Object.assign(window, { __screenUI: { events, patch: (value: object) => Object.assign(state, value) } })
const diagnostics = (): ScreenDiagnostics => ({ source: state.source as ScreenDiagnostics['source'], audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: { width: 1920, height: 654, framesPerSecond: state.fps }, roundTripTimeMs: 42 })
const viewerParticipants: VoiceVolumeParticipant[] = [
  { accountId: 'member-speaking', id: 'member-speaking', microphoneMuted: false, name: 'Участник говорит', speaking: true, volume: 100 },
  { accountId: 'member-sharing', id: 'member-sharing', microphoneMuted: true, name: 'Участник показывает экран', speaking: false, volume: 100 },
]
const viewerScreens: ScreenViewerCard[] = [
  { accountId: 'local-user', hasAudio: false, id: 'local-screen', isLocal: true, participantId: 'local-user', participantName: 'Локальная трансляция' },
  { accountId: 'member-sharing', hasAudio: true, id: 'remote-screen', isLocal: false, participantId: 'member-sharing', participantName: 'Участник показывает экран' },
]
const pinia = createPinia()
const authors = useAuthorDirectory(pinia)
authors.acceptOwnProfile({ account_id: 'local-user', login: 'local', display_name: 'Локальный участник', role: 'MEMBER', avatar_url: '/avatar', profile_revision: 2 })
authors.acceptOwnProfile({ account_id: 'member-speaking', login: 'speaker', display_name: 'Участник говорит', role: 'MEMBER', avatar_url: '/avatar', profile_revision: 3 })
authors.acceptOwnProfile({ account_id: 'member-sharing', login: 'sharing', display_name: 'Участник показывает экран', role: 'MEMBER' })
const IntermittentDiagnosis = defineComponent({
  setup() {
    let readCount = 0
    const selected = ref<ScreenViewerCard | null>({
      id: 'intermittent-screen', hasAudio: true, participantId: 'a', participantName: 'A',
      readReceiverStats: async () => {
        readCount += 1
        if (readCount % 8 !== 1) return undefined
        return { timestamp: Date.now(), framesDecoded: readCount * 30, framesDropped: 0, bytesReceived: readCount * 1024 }
      },
    })
    const { metrics, sampledAt } = useScreenReceiverDiagnostics(selected, () => false)
    return () => h(DiagnosisPanel, {
      selectedId: 'intermittent-screen', ended: false, hasAudio: true, local: false,
      videoReady: true, presentedFps: 30, presentedFrames: 30, sampledAt: sampledAt.value, metrics: metrics.value,
    })
  },
})
const viewerStrip = () => h('section', { class: 'voice-room', style: `height:${params.get('height') ?? '760'}px` }, [
  h(ScreenViewer, {
    audioMuted: state.audioMuted,
    cards: viewerScreens,
    deafened: false,
    ended: false,
    error: null,
    expanded: false,
    mini: false,
    ownScreenSharing: !params.has('watching-remote'),
    pinned: false,
    participants: viewerParticipants,
    screenWatcherIds: params.has('watching-remote') ? ['local-user', 'member-speaking'] : ['member-speaking'],
    selfAccountId: 'local-user',
    selfMicrophoneMuted: true,
    selfMicrophoneUnavailable: false,
    selfName: 'Очень длинное имя владельца трансляции для проверки ширины',
    selfSpeaking: false,
    selectedAudioVolume: 100,
    selectedId: params.has('watching-remote') || params.has('remote-audio') ? 'remote-screen' : 'local-screen',
    sourceDiagnostics: diagnostics(),
    onToggleAudio: () => { state.audioMuted = !state.audioMuted },
    onStopScreen: () => events.push('stop-screen'),
  }),
])
createApp({ render: () => params.has('viewer-strip') ?
  h('main', { style: 'width:100%;padding:0' }, [viewerStrip()]) :
  h('main', { style: 'padding:16px;max-width:720px;margin:auto' }, [
    h('h1', { style: 'font-size:1rem' }, 'Проверка демонстрации'),
    params.has('diagnosis-flapping') ? h(IntermittentDiagnosis) :
    params.has('diagnosis-local') ? h(DiagnosisPanel, { selectedId: 'local-screen', ended: false, hasAudio: false, local: true, videoReady: true, presentedFps: 30, presentedFrames: 900, sampledAt: null, metrics: null }) :
    params.has('diagnosis') ? h(DiagnosisPanel, { selectedId: 'synthetic:screen', ended: false, hasAudio: state.hasAudio, local: false, videoReady: true, presentedFps: 30, presentedFrames: 900, sampledAt: state.sampledAt, metrics: null }) :
    params.has('sender') ? h(ScreenDiagnosticsPanel, { diagnostics: diagnostics(), profile: state.profile === 'null' ? null : state.profile as any, onRefresh: () => events.push('refresh') }) :
    params.has('receiver') ? h(ScreenReceiverDiagnosticsPanel, { actualVideoQuality: '1920 × 654 · 1 FPS', hasAudio: false, isLocal: false, metrics: null, sampledAt: null, targetProfile: '1080p · 60 FPS', participantName: 'Synthetic QA' }) : [
      h('button', { id: 'opener', onClick: () => { state.open = true } }, 'Показать экран'),
      state.open ? h(ScreenShareSetupDialog, { initialProfile: state.profile as any, updating: params.has('updating'), onCancel: () => { events.push('cancel'); state.open = false }, onStart: (profile: string, mode: string) => { events.push({ profile, mode, activation: navigator.userActivation.isActive }); state.open = false } }) : null,
    ],
  ]) }).use(pinia).mount('#app')
