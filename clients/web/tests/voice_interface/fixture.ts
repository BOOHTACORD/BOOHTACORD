import { createApp, h, reactive } from 'vue'
import { createPinia } from 'pinia'
import ConversationPane from '../../src/conversation/ConversationPane.vue'
import VoiceDock from '../../src/voice/VoiceDock.vue'
import { browserSupportsTouchPtt } from '../../src/voice/touch_ptt'
import WorkspaceMembersPanel from '../../src/workspace/WorkspaceMembersPanel.vue'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import type { VoiceDisconnectNotice } from '../../src/voice/disconnect_notice/model'
import type { VoiceConnectionState, ScreenShareState } from '../../src/voice/connection_store'
import type { VoiceActivationMode } from '../../src/voice/activation_store'
import type { ScreenViewerCard } from '../../src/voice/screen_viewer_controller'
import '../../src/style.css'

const params = new URLSearchParams(location.search)
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
const channel = { id: 'voice-fixture', name: 'Общая голосовая комната', kind: 'VOICE' as const, position: 0, admissionClosed: false }
const initialMode = params.get('mode') === 'PTT' ? 'PTT' : 'VAD'
const state = reactive({ state: 'CONNECTED' as VoiceConnectionState, active: true, muted: initialMode === 'PTT', pttPressed: false, deafened: false, denied: false, deafenChanging: false, mode: initialMode as VoiceActivationMode, screen: 'IDLE' as ScreenShareState, selected: null as string | null, error: null as string | null, notice: null as VoiceDisconnectNotice | null, voiceVolumeParticipants: [{ id: 'peer', accountId: 'peer', name: 'Тестовый участник', microphoneMuted: false, speaking: false, volume: 100 }] })
const events: string[] = []
function toggleMicrophone() { events.push('microphone'); state.muted = !state.muted }
function setTouchPttPressed(pressed: boolean) { events.push(pressed ? 'ptt:press' : 'ptt:release'); state.pttPressed = pressed; state.muted = !pressed }
function toggleDeafen() { events.push('deafen'); state.deafened = !state.deafened }
function leave() { events.push('leave'); state.state = 'LEAVING' }
function startScreen() { events.push('startScreen'); state.screen = 'STARTING' }
function stopScreen() { events.push('stopScreen'); state.screen = 'STOPPING' }
const cards: ScreenViewerCard[] = [{ id: 'screen-peer', participantId: 'peer', participantName: 'Тестовый участник', isLocal: false, hasAudio: false }]
const pinia = createPinia()
const authors = useAuthorDirectory(pinia)
authors.acceptOwnProfile({ account_id: 'self', login: 'self', display_name: 'Тестовый клиент', role: 'MEMBER', avatar_url: '/avatar', profile_revision: 2 })
authors.acceptOwnProfile({ account_id: 'peer', login: 'peer', display_name: 'Тестовый участник', role: 'MEMBER', avatar_url: '/avatar', profile_revision: 3 })
Object.assign(window, { __voiceFixture: { patch: (patch: Partial<typeof state>) => Object.assign(state, patch), events } })
createApp({ render: () => h('div', { class: 'app-shell', style: 'display:grid;grid-template-columns:280px minmax(0,1fr);height:100dvh' }, [
  h('aside', { class: params.has('closed') ? 'sidebar' : 'sidebar is-open', style: 'position:relative;width:280px;transform:none;min-width:0;z-index:1' }, [
    h('h1', { style: 'padding:16px;font-size:1rem' }, 'BOOHTACORD'),
    params.has('participants')
      ? h('div', { 'data-testid': 'dock-participants', style: 'flex:1;min-height:48px;padding:12px' }, 'Участники · Тестовый участник')
      : h('div', { style: 'flex:1' }),
    params.has('members') ? h(WorkspaceMembersPanel, { activeVoiceChannel: state.active && state.state !== 'LEAVING' ? channel : null, selectedVoiceChannel: channel, participants: [{ id: 'peer', accountId: 'peer', name: 'Тестовый участник', speaking: false, microphoneMuted: false, volume: 100 }], presenceResolver: (_id: string, fallback: any) => fallback, role: 'MEMBER', selfMicrophoneMuted: false, selfMicrophoneUnavailable: false, selfName: 'Тестовый клиент', open: true, modal: false, style: 'position:relative;width:100%' }) : null,
    h(VoiceDock, { class: 'mobile-voice-dock', channel: state.active ? channel : null, activeSession: state.active, error: state.error, notice: state.notice, activationMode: state.mode, touchPttEnabled: params.get('touchPtt') === '1' || browserSupportsTouchPtt(), setTouchPttPressed, deafened: state.deafened, deafenChanging: state.deafenChanging, microphoneMuted: state.muted, microphonePermissionDenied: state.denied, screenShareState: state.screen, connectionQuality: 'GOOD', pingMs: 42, participantCount: 2, state: state.state, onLeave: leave, onStartScreen: startScreen, onStopScreen: stopScreen, onToggleMicrophone: toggleMicrophone, onToggleDeafen: toggleDeafen }),
  ]),
  h('main', { class: 'main', style: 'min-width:0' }, [h(ConversationPane, {
    accountId: 'self', activeVoiceChannel: state.active ? channel : null, visible: true, channel, directMessage: null, navOpen: false, membersOpen: false, showMembers: false,
    selfDisplayName: 'Тестовый клиент', selfDeafened: state.deafened, voiceError: state.error, voiceIsActive: state.active, voiceState: state.state, activationMode: state.mode, deafenChanging: state.deafenChanging, voiceTransferRequired: false,
    screenError: null, screenDiagnostics: { audioTrack: 'UNKNOWN', connectionQuality: 'UNKNOWN', source: 'UNKNOWN', measured: null }, screenProfile: null, selectedScreenProfile: 'P1080_30', screenState: state.screen,
    // Intentionally retain stale cards/selection after leave to test the presentation boundary.
    screenViewerCards: state.screen === 'IDLE' ? [] : cards, selectedScreenStreamId: state.selected, selectedScreenAudioVolume: 100, screenAudioMuted: false, screenViewerEnded: false, screenViewerError: null,
    selfMicrophoneMuted: state.muted, selfMicrophoneUnavailable: state.denied, selfSpeaking: false, voiceVolumeError: null, voiceVolumeParticipants: state.voiceVolumeParticipants,
    voiceRoster: { channelId: channel.id, revision: 1, participants: [] }, toggleMicrophone, toggleDeafen,
    onJoin: (_id: string, _transfer?: boolean, mode?: string) => { events.push(mode === 'listener' ? 'listener' : 'join'); state.state = 'JOINING' }, onLeave: leave, onStartScreen: startScreen, onStopScreen: stopScreen,
  })]),
]) }).use(pinia).mount('#app')

// A narrow viewport has no persistent desktop sidebar; the production dock remains below the room.
if (innerWidth < 1024) {
  const shell = document.querySelector<HTMLElement>('.app-shell')!
  shell.style.gridTemplateColumns = 'minmax(0,1fr)'
  shell.style.gridTemplateRows = 'minmax(0,1fr) auto'
  const aside = document.querySelector<HTMLElement>('aside')!
  aside.style.cssText = 'position:relative;width:100%;transform:none;min-width:0;order:2;z-index:1'
  aside.querySelector('h1')!.remove()
}
