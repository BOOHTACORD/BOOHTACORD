<script setup lang="ts">
import type { TopologyChannel } from '../channel/topology_client'
import ConversationPane from '../conversation/ConversationPane.vue'
import type { DirectMessageListItem } from '../direct_message/direct_message_client'
import type { VoiceActivationMode } from '../voice/activation_store'
import type { ScreenProfile } from '../voice/livekit_gateway'
import { useVoiceConnectionStore } from '../voice/connection_store'
import type { VoiceRoomRoster } from '../voice/voice_roster_client'
import SettingsWorkspaceHeader from '../shared/workspace_header/SettingsWorkspaceHeader.vue'
import type { useWorkspaceVoiceControls } from './voice_controls'

type VoiceConnection = ReturnType<typeof useVoiceConnectionStore>
type WorkspaceVoiceControls = ReturnType<typeof useWorkspaceVoiceControls>

defineProps<{
  accountId: string
  activeVoiceChannel: TopologyChannel | null
  panel: 'none' | 'admin' | 'audio' | 'profile'
  channel: TopologyChannel | null
  directMessage: DirectMessageListItem | null
  joinVoice: WorkspaceVoiceControls['joinVoice']
  leaveVoice: WorkspaceVoiceControls['leaveVoice']
  activationMode: VoiceActivationMode
  startScreen: (profile: ScreenProfile) => void
  selectedScreenProfile: ScreenProfile
  navOpen: boolean
  membersOpen: boolean
  showMembers: boolean
  selfDisplayName: string | null
  voiceConnection: VoiceConnection
  voiceRoster?: VoiceRoomRoster | null
  voiceRosterError?: string | null
}>()
const emit = defineEmits<{ openSearch: []; returnVoice: [channelId: string]; toggleNav: []; toggleMembers: []; closePanel: [panel: 'admin' | 'audio' | 'profile'] }>()
</script>

<template>
  <div v-if="panel === 'admin'" class="workspace-main-panel workspace-main-panel--admin" data-testid="admin-workspace-panel">
    <SettingsWorkspaceHeader panel="admin" :nav-expanded="navOpen" @toggle-navigation="emit('toggleNav')" @close="emit('closePanel', 'admin')" />
    <slot name="admin" />
  </div>
  <div v-else-if="panel === 'audio'" class="workspace-main-panel workspace-main-panel--audio" data-testid="audio-workspace-panel">
    <SettingsWorkspaceHeader panel="audio" :nav-expanded="navOpen" @toggle-navigation="emit('toggleNav')" @close="emit('closePanel', 'audio')" />
    <slot name="audio" />
  </div>
  <div v-else-if="panel === 'profile'" class="workspace-main-panel workspace-main-panel--profile" data-testid="profile-workspace-panel">
    <SettingsWorkspaceHeader panel="profile" :nav-expanded="navOpen" @toggle-navigation="emit('toggleNav')" @close="emit('closePanel', 'profile')" />
    <slot name="profile" />
  </div>
  <ConversationPane
    v-show="panel === 'none'"
    :account-id="accountId"
    :active-voice-channel="activeVoiceChannel"
    :visible="panel === 'none'"
    :channel="channel"
    :activation-mode="activationMode"
    :direct-message="directMessage"
    :nav-open="navOpen"
    :members-open="membersOpen"
    :show-members="showMembers"
    :self-display-name="selfDisplayName"
    :screen-diagnostics="voiceConnection.screenDiagnostics"
    :screen-error="voiceConnection.screenError"
    :screen-profile="voiceConnection.screenProfile"
    :selected-screen-profile="selectedScreenProfile"
    :screen-state="voiceConnection.screenState"
    :screen-viewer-cards="voiceConnection.screenViewerCards"
    :screen-viewer-ended="voiceConnection.screenViewerEnded"
    :screen-viewer-error="voiceConnection.screenViewerError"
    :selected-screen-audio-volume="voiceConnection.selectedScreenAudioVolume"
    :screen-audio-muted="voiceConnection.screenAudioMuted"
    :selected-screen-stream-id="voiceConnection.selectedScreenStreamId"
    :self-microphone-muted="voiceConnection.microphoneMuted"
    :self-microphone-unavailable="voiceConnection.microphonePermissionDenied"
    :self-deafened="voiceConnection.deafened"
    :deafen-changing="voiceConnection.deafenChanging"
    :self-speaking="voiceConnection.selfSpeaking"
    :voice-error="voiceConnection.error"
    :voice-disconnect-notice="voiceConnection.disconnectNotice"
    :voice-is-active="channel?.id === voiceConnection.active?.channelId"
    :voice-state="voiceConnection.state"
    :voice-transfer-required="voiceConnection.transferRequired"
    :voice-volume-error="voiceConnection.voiceVolumeError"
    :voice-volume-participants="voiceConnection.voiceVolumeParticipants"
    :toggle-microphone="voiceConnection.toggleMicrophone"
    :toggle-deafen="voiceConnection.toggleDeafen"
    :voice-roster="voiceRoster ?? null"
    :voice-roster-error="voiceRosterError ?? null"
    @clear-screen-stream="voiceConnection.clearScreenStream"
    @join="joinVoice"
    @leave="leaveVoice"
    @refresh-screen="voiceConnection.refreshScreenDiagnostics"
    @return-voice="emit('returnVoice', $event)"
    @retry-screen-stream="voiceConnection.retryScreenStream"
    @select-screen-stream="voiceConnection.selectScreenStream"
    @set-participant-volume="voiceConnection.setParticipantVolume"
    @set-screen-volume="voiceConnection.setScreenVolume"
    @toggle-screen-audio="voiceConnection.toggleScreenAudio"
    @start-screen="startScreen"
    @stop-screen="voiceConnection.stopScreen"
    @transfer="joinVoice($event, true)"
    @toggle-nav="emit('toggleNav')"
    @toggle-members="emit('toggleMembers')"
    @open-search="emit('openSearch')"
  />
</template>
