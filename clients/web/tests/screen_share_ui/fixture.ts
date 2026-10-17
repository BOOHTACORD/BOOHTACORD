import { createApp, h, reactive } from 'vue'
import ScreenShareSetupDialog from '../../src/voice/ScreenShareSetupDialog.vue'
import ScreenDiagnosticsPanel from '../../src/voice/ScreenDiagnosticsPanel.vue'
import ScreenReceiverDiagnosticsPanel from '../../src/voice/ScreenReceiverDiagnosticsPanel.vue'
import DiagnosisPanel from '../../src/voice/viewer_diagnosis/Panel.vue'
import type { ScreenDiagnostics } from '../../src/voice/screen_diagnostics'
import '../../src/style.css'
const params = new URLSearchParams(location.search)
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
if (params.has('unsupported')) Object.defineProperty(navigator, 'mediaDevices', { value: {}, configurable: true })
const events: unknown[] = []
const state = reactive({ open: true, profile: params.get('profile') ?? 'P1080_60', source: 'ACTIVE', fps: 1, sampledAt: null as number | null })
Object.assign(window, { __screenUI: { events, patch: (value: object) => Object.assign(state, value) } })
const diagnostics = (): ScreenDiagnostics => ({ source: state.source as ScreenDiagnostics['source'], audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: { width: 1920, height: 654, framesPerSecond: state.fps }, roundTripTimeMs: 42 })
createApp({ render: () => h('main', { style: 'padding:16px;max-width:720px;margin:auto' }, [
  h('h1', { style: 'font-size:1rem' }, 'Проверка демонстрации'),
  params.has('diagnosis') ? h(DiagnosisPanel, { selectedId: 'synthetic:screen', ended: false, hasAudio: false, local: false, videoReady: true, presentedFps: 30, presentedFrames: 900, sampledAt: state.sampledAt, metrics: null }) :
  params.has('sender') ? h(ScreenDiagnosticsPanel, { diagnostics: diagnostics(), profile: state.profile === 'null' ? null : state.profile as any, onRefresh: () => events.push('refresh') }) :
  params.has('receiver') ? h(ScreenReceiverDiagnosticsPanel, { actualVideoQuality: '1920 × 654 · 1 FPS', hasAudio: false, isLocal: false, metrics: null, sampledAt: null, targetProfile: '1080p · 60 FPS', participantName: 'Synthetic QA' }) : [
    h('button', { id: 'opener', onClick: () => { state.open = true } }, 'Показать экран'),
    state.open ? h(ScreenShareSetupDialog, { initialProfile: state.profile as any, updating: params.has('updating'), onCancel: () => { events.push('cancel'); state.open = false }, onStart: (profile: string, mode: string) => { events.push({ profile, mode, activation: navigator.userActivation.isActive }); state.open = false } }) : null,
  ],
]) }).mount('#app')
