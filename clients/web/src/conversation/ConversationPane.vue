<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import type { VoiceDisconnectNotice } from '../voice/disconnect_notice/model'
import DisconnectNotice from '../voice/disconnect_notice/Notice.vue'
import { computed } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import DirectMessageConversation from '../direct_message/DirectMessageConversation.vue'
import type { DirectMessageListItem } from '../direct_message/direct_message_client'
import type { ScreenShareState, VoiceConnectionState } from '../voice/connection_store'
import type { VoiceActivationMode } from '../voice/activation_store'
import type { ScreenProfile, VoiceJoinMode } from '../voice/livekit_gateway'
import type { ScreenDiagnostics } from '../voice/screen_diagnostics'
import ScreenViewer from '../voice/ScreenViewer.vue'
import VoicePrejoin from '../voice/VoicePrejoin.vue'
import VoiceRoomConnected from '../voice/VoiceRoomConnected.vue'
import type { ScreenViewerCard } from '../voice/screen_viewer_controller'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'
import type { VoiceRoomRoster } from '../voice/voice_roster_client'
import { useConversationScreenState } from '../voice/use_conversation_screen_state'
import TextConversation from './TextConversation.vue'
import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import ConversationOverflowMenu from './ConversationOverflowMenu.vue'
const props = withDefaults(defineProps<{
  searchExpanded?: boolean
  accountId: string; activeVoiceChannel: TopologyChannel | null
  miniPlayerTarget?: HTMLElement | null
  visible: boolean
  channel: TopologyChannel | null
  directMessage: DirectMessageListItem | null
  navOpen: boolean
  membersOpen: boolean
  showMembers: boolean
  selfDisplayName: string | null; selfDeafened: boolean
  voiceError: string | null; voiceDisconnectNotice?: VoiceDisconnectNotice | null
  voiceIsActive: boolean
  deafenChanging?: boolean
  voiceState: VoiceConnectionState
  activationMode: VoiceActivationMode
  voiceTransferRequired: boolean
  screenError: string | null
  screenViewerCards: ScreenViewerCard[]
  screenWatcherIds?: string[]
  screenViewerEnded: boolean
  screenViewerError: string | null
  screenDiagnostics: ScreenDiagnostics
  screenProfile: ScreenProfile | null
  selectedScreenProfile?: ScreenProfile
  screenState: ScreenShareState
  selectedScreenStreamId: string | null
  selectedScreenAudioVolume: number
  screenAudioMuted: boolean
  selfMicrophoneMuted: boolean
  selfMicrophoneUnavailable: boolean
  selfSpeaking: boolean
  voiceVolumeError: string | null
  voiceVolumeParticipants: VoiceVolumeParticipant[]
  toggleMicrophone: () => void
  toggleDeafen: () => void
  voiceRoster?: VoiceRoomRoster | null
  voiceRosterError?: string | null
}>(), {
  screenViewerCards: () => [],
  screenWatcherIds: () => [],
  screenViewerEnded: false,
  selectedScreenProfile: 'P1080_30',
  selectedScreenStreamId: null,
})
const emit = defineEmits<{ clearScreenStream: []; join: [channelId: string, transfer?: boolean, joinMode?: VoiceJoinMode]; leave: []; openSearch: []; refreshScreen: []; retryScreenStream: [automatic?: boolean]; returnVoice: [channelId: string]; selectScreenStream: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setParticipantVolume: [id: string, percent: number]; setScreenVolume: [percent: number]; toggleScreenAudio: []; startScreen: [profile: ScreenProfile]; stopScreen: []; transfer: [channelId: string]; toggleNav: []; toggleMembers: [] }>()
const selectedScreenProfile = computed(() => props.selectedScreenProfile)
const { screenExpanded, screenPinned,
  voiceChannel, miniVisible, keepVoiceRoom, selectedScreenName, screenViewerRef, watchScreen, dismissLocalPreview } = useConversationScreenState(props)
function toggleScreenPin(): void {
  if (screenPinned.value && (!props.visible || props.directMessage || props.channel?.kind !== 'VOICE')) {
    if (props.activeVoiceChannel) emit('returnVoice', props.activeVoiceChannel.id)
    screenExpanded.value = false
  }
  screenPinned.value = !screenPinned.value
}
function clearScreenPreview(): void {
  dismissLocalPreview()
  emit('clearScreenStream')
}
</script>
<template>
  <section class="conversation-pane" aria-live="polite">
    <template v-if="directMessage">
      <DirectMessageConversation :key="directMessage.id" :account-id="accountId" :active="visible" :direct-message-id="directMessage.id" :other-participant-id="directMessage.otherParticipantId" :other-participant-display-name="directMessage.otherParticipantDisplayName" :nav-open="navOpen" @toggle-nav="emit('toggleNav')" />
    </template>
    <template v-else-if="!channel">
      <header class="main-header conversation-header">
        <div class="main-title"><h2>Выберите канал</h2><small>Рабочая область</small></div>
        <WorkspaceHeaderActions :members-expanded="false" :nav-expanded="navOpen" :show-members="false" @toggle-navigation="emit('toggleNav')" />
      </header>
      <p>Навигация показывает только данные, полученные от текущей серверной сессии.</p>
    </template>
    <template v-else-if="channel.kind === 'TEXT'">
      <TextConversation :key="channel.id" :account-id="accountId" :active="visible" :channel-id="channel.id" :channel-name="channel.name" :channel-description="channel.description" :nav-open="navOpen" :members-open="membersOpen" :show-members="showMembers" @toggle-nav="emit('toggleNav')" @toggle-members="emit('toggleMembers')" />
    </template>
    <template v-if="voiceChannel && keepVoiceRoom">
      <Teleport :to="miniVisible && miniPlayerTarget ? miniPlayerTarget : 'body'" :disabled="!screenExpanded && !(miniVisible && miniPlayerTarget)">
        <section class="voice-room" :class="{ 'voice-room--screen-expanded': screenExpanded, 'voice-room--mini': miniVisible }">
          <header class="main-header conversation-header">
            <span class="conversation-symbol" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 4V5L7 9H3ZM16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11" /></svg></span>
            <div class="main-title"><h2 :title="voiceChannel.name">{{ voiceChannel.name }}</h2><small>{{ voiceIsActive && voiceState === 'LEAVING' ? 'Выходим…' : selectedScreenName && voiceIsActive ? `${voiceVolumeParticipants.length + 1} участника · ${screenViewerCards.length} трансляции` : voiceIsActive ? `${voiceVolumeParticipants.length + 1} участника в голосовом канале` : voiceRosterError ? 'Голосовой канал · состав недоступен' : voiceRoster ? voiceRoster.participants.length ? `Голосовой канал · сейчас: ${voiceRoster.participants.length}` : 'Голосовой канал · пока пусто' : 'Голосовой канал · проверяем состав' }}</small></div>
            <WorkspaceHeaderActions :members-expanded="membersOpen" :nav-expanded="navOpen" :show-members="showMembers" @toggle-members="emit('toggleMembers')" @toggle-navigation="emit('toggleNav')">
              <button v-action-hint class="header-action" type="button" aria-label="Найти сообщение" :aria-expanded="Boolean(searchExpanded)" aria-controls="search-aside-panel" @click="emit('openSearch')"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6"/><path d="m16 16 4 4"/></svg></button>
              <template #overflow><ConversationOverflowMenu :search-expanded="searchExpanded" search-controls="search-aside-panel" menu-label="Действия голосового канала" :show-members="showMembers" :members-open="membersOpen" @search="emit('openSearch')" @toggle-members="emit('toggleMembers')" /></template>
            </WorkspaceHeaderActions>
          </header>
          <div v-if="voiceChannel.admissionClosed" class="state state-error" :role="voiceDisconnectNotice ? undefined : 'status'">
            <DisconnectNotice v-if="voiceDisconnectNotice" :notice="voiceDisconnectNotice" />
            <template v-else>Вход в этот канал закрыт администратором. Отзыв media-доступа ещё подтверждается. <span v-if="voiceError">{{ voiceError }}</span></template>
            <button v-if="voiceIsActive" type="button" @click="emit('leave')">Выйти из голосового канала</button>
          </div>
          <template v-if="(voiceIsActive || (screenPinned && activeVoiceChannel?.id === voiceChannel.id)) && voiceState !== 'LEAVING' && (screenViewerCards.length || selectedScreenStreamId || screenViewerEnded)">
            <ScreenViewer
              ref="screenViewerRef" v-show="selectedScreenStreamId !== null" :audio-muted="screenAudioMuted" :cards="screenViewerCards" :deafened="selfDeafened" :ended="screenViewerEnded" :error="screenViewerError" :expanded="screenExpanded" :mini="miniVisible" :own-screen-sharing="screenState === 'SHARING'" :pinned="screenPinned" :participants="voiceVolumeParticipants" :screen-watcher-ids="screenWatcherIds" :self-account-id="accountId" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-name="selfDisplayName" :self-speaking="selfSpeaking" :selected-audio-volume="selectedScreenAudioVolume" :selected-id="selectedScreenStreamId"
              @clear="clearScreenPreview" @retry="emit('retryScreenStream', $event)" @select="(id, video, audio) => emit('selectScreenStream', id, video, audio)" @set-audio-volume="emit('setScreenVolume', $event)" @toggle-audio="emit('toggleScreenAudio')"
              @pin="toggleScreenPin" @change-quality="emit('startScreen', screenProfile ?? selectedScreenProfile)" @stop-screen="emit('stopScreen')"
              :source-diagnostics="screenDiagnostics" @update:expanded="screenExpanded = $event"
            />
          </template>
          <div v-if="!voiceIsActive || voiceState === 'LEAVING' || !selectedScreenStreamId" class="room-wrap">
            <VoiceRoomConnected :activation-mode="activationMode" :deafen-changing="deafenChanging" v-if="!voiceChannel.admissionClosed && voiceIsActive" :room-name="voiceChannel.name" :voice-state="voiceState" :screen-state="screenState" :screen-error="screenError" :screen-diagnostics="screenDiagnostics" :screen-profile="screenProfile" :selected-screen-profile="selectedScreenProfile" :screen-viewer-cards="screenViewerCards" :screen-watcher-ids="screenWatcherIds" :voice-volume-error="voiceVolumeError" :voice-volume-participants="voiceVolumeParticipants" :self-account-id="accountId" :self-name="selfDisplayName" :self-deafened="selfDeafened" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-speaking="selfSpeaking" :toggle-microphone="toggleMicrophone" :toggle-deafen="toggleDeafen" @set-volume="(id, percent) => emit('setParticipantVolume', id, percent)" @watch-screen="watchScreen" @start-screen="emit('startScreen', $event)" @stop-screen="emit('stopScreen')" @leave="emit('leave')" @refresh-screen="emit('refreshScreen')" />
            <VoicePrejoin :notice="voiceDisconnectNotice" v-else-if="!voiceChannel.admissionClosed" :channel-id="voiceChannel.id" :voice-error="voiceError" :voice-state="voiceState" :voice-transfer-required="voiceTransferRequired" :roster="voiceRoster ?? null" :roster-error="voiceRosterError ?? null" @join="(id, transfer, mode) => emit('join', id, transfer, mode)" @transfer="emit('transfer', $event)" />
          </div>
        </section>
      </Teleport>
    </template>
  </section>
</template>
