<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import GuildName from '../guild/profile/GuildName.vue'
import ChannelTopologyActions from '../channel/member_topology/ChannelTopologyActions.vue'
import type { TopologyChannel } from '../channel/topology_client'
import AdminConfirmation from '../channel/AdminConfirmation.vue'
import { buildVoiceNavigationPresence } from '../channel/voice_navigation_presence'
import { createVoiceRosterRealtime, createVoiceRosterReconnectGate } from '../voice/voice_roster_realtime'
import DirectMessageNavigation from '../direct_message/DirectMessageNavigation.vue'
import ShortcutStatus from '../voice/shortcuts/Status.vue'
import VoiceDock from '../voice/VoiceDock.vue'
import ScreenShareSetupDialog from '../voice/ScreenShareSetupDialog.vue'
import AudioSettings from '../voice/AudioSettings.vue'
import { useMessageStore } from '../conversation/message_store'
import { useRealtimeStore } from '../realtime/realtime_store'
import { createWorkspaceRealtime } from './workspace_realtime'
import { bindWorkspaceLogout } from './logout_flow'
import { expireWorkspaceSession } from './session_expiry_media'
import { useWorkspaceVoiceControls } from './voice_controls'
import WorkspaceMain from './WorkspaceMain.vue'
import WorkspaceMembersPanel from './WorkspaceMembersPanel.vue'
import WorkspaceSidebarTabs from './WorkspaceSidebarTabs.vue'
import WorkspaceUserFooter from './WorkspaceUserFooter.vue'
import { useGuildPresence } from '../identity/guild_presence'
import ProfileSettings from '../identity/ProfileSettings.vue'
import { useCurrentProfile } from '../identity/current_profile'
import { useAuthorDirectoryLifecycle } from '../identity/author_directory_lifecycle'
import AdminPanel from '../admin/panel/AdminPanel.vue'
import type { AdminSection } from '../admin/panel/admin_section'
import SearchLauncher from '../search/SearchLauncher.vue'
import WorkspaceSearchPanel from './search/WorkspaceSearchPanel.vue'
import { usePermissionStore } from '../authorization/permission_store'
import { useScreenShareSetup } from './screen_share_setup'
import { useWorkspaceNavigation } from './workspace_navigation'
import ConnectionStatus from './connection_status/Status.vue'
import { navigateWithSettingsGuard } from './settings_exit_guard'
import type { ActionScope } from '../telemetry/action_scope/scope'
import { bindWorkspaceReady } from './ready_lifecycle/bind'
const props = defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR'; accountId: string;readiness?:ActionScope }>()
const emit = defineEmits<{ sessionExpired: []; loggedOut: [] }>()
const adminSection = ref<AdminSection>('members')
const { activeVoiceChannel, audioSettings, loadAudioDevices, joinVoice, leaveVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel: selectWorkspaceChannel, selectDirectMessage: selectWorkspaceDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection } = useWorkspaceVoiceControls(props.accountId)
const { confirmScreenShare, openScreenShareSetup, screenShareSetupOpen, selectedScreenProfile, selectedScreenMode } = useScreenShareSetup(() => voiceConnection.screenState, startScreen, props.accountId)
const { activePanel, closeDrawers, directMessageStore, memberHeaderExpandedState, membersOpen, modalDrawer, navOpen, openDirectMessageFromMember, returnToVoice, selectedDirectMessage, selectChannel, selectDirectMessage, selectOpenedDirectMessage, sidebarSection, toggleMembers, toggleNavigation, togglePanel, voiceStageWide } = useWorkspaceNavigation(props.role, selectedChannel, topologyStore, selectWorkspaceChannel, selectWorkspaceDirectMessage)
const profileSettings = ref<{ hasUnsavedChanges: boolean } | null>(null)
const profileExitConfirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
const messageStore = useMessageStore()
const realtimeStore = useRealtimeStore()
const expireSession = () => expireWorkspaceSession(voiceConnection, () => emit('sessionExpired'))
const voiceRoster = createVoiceRosterRealtime(undefined, expireSession)
const shouldReconnectVoiceRoster = createVoiceRosterReconnectGate(realtimeStore.state === 'CONNECTED')
const { busy: logoutBusy, error: logoutError, signOut } = bindWorkspaceLogout(voiceConnection, leaveVoice, realtimeStore, () => emit('loggedOut'))
const guildPresence = useGuildPresence()
const guildMemberCount = ref<number | null>(null)
const permissions = usePermissionStore()
const workspaceRealtime = createWorkspaceRealtime({ topology: topologyStore, messages: messageStore, directMessages: directMessageStore }, realtimeStore, guildPresence, voiceConnection, props.accountId, expireSession)
watch(() => realtimeStore.state, (state) => { if (state === 'ERROR' || state === 'DISCONNECTED') guildPresence.invalidate(); if (state === 'CONNECTED' && shouldReconnectVoiceRoster()) voiceRoster.reconnect() })
const { profile, profileError, profileLoading, refreshProfile, setProfile } = useCurrentProfile()
useAuthorDirectoryLifecycle(profile)
const voiceNavigationPresence = computed(() => buildVoiceNavigationPresence(activeVoiceChannel.value?.id ?? null, profile.value, voiceConnection))
async function beforeWorkspaceNavigation(action: () => void | Promise<unknown>): Promise<void> {
  const hasUnsavedProfileChanges = activePanel.value === 'profile' && Boolean(profileSettings.value?.hasUnsavedChanges)
  await navigateWithSettingsGuard(hasUnsavedProfileChanges, async () => Boolean(await profileExitConfirmation.value?.ask('Введённое имя или пароль ещё не сохранены. Если уйти, эти данные будут потеряны. Продолжить?')), action)
}
function requestPanel(panel: 'admin' | 'audio' | 'profile' | 'search'): Promise<void> { return beforeWorkspaceNavigation(() => togglePanel(panel)) }
function requestGuildPanel(): Promise<void> { return props.role === 'ADMINISTRATOR' ? requestPanel('admin') : Promise.resolve() }
function requestSelectChannel(channel: TopologyChannel): Promise<void> { return beforeWorkspaceNavigation(() => selectChannel(channel)) }
function requestSelectDirectMessage(id: string): Promise<void> { return beforeWorkspaceNavigation(() => selectDirectMessage(id)) }
function requestOpenDirectMessage(id: string): Promise<void> { return beforeWorkspaceNavigation(() => selectOpenedDirectMessage(id)) }
function requestReturnToVoice(channelId: string): Promise<void> { return beforeWorkspaceNavigation(() => returnToVoice(channelId)) }
function requestOpenDirectMessageFromMember(userId: string): Promise<void> { return beforeWorkspaceNavigation(() => openDirectMessageFromMember(userId)) }
function requestWorkspaceScrimClose(): Promise<void> { return beforeWorkspaceNavigation(() => { closeDrawers(); activePanel.value = 'none' }) }
function refreshTopology(): void { void topologyStore.refresh() }
bindWorkspaceReady({ readiness: props.readiness,
  start: () => { permissions.start(props.accountId); voiceRoster.start(); workspaceRealtime.start() },
  refresh: () => Promise.all([topologyStore.refresh(), directMessageStore.refreshNavigation(), refreshProfile()]),
  failed: () => Boolean(topologyStore.error || directMessageStore.error || profileError.value),
  stop: () => { permissions.stop(); voiceRoster.stop(); workspaceRealtime.stop() },
})
</script>
<template>
  <div class="app-frame">
    <a class="gc-sr-only" href="#main-region">Перейти к содержимому</a>
    <ShortcutStatus :message="voiceActivation.shortcutStatus" />
      <div class="gc-shell" :class="{ 'no-aside': (activePanel === 'search' && voiceStageWide) || (activePanel !== 'search' && (voiceStageWide || selectedDirectMessage || activePanel !== 'none')), 'search-active': activePanel === 'search', 'voice-stage-wide': voiceStageWide, 'members-collapsed': membersOpen && !voiceStageWide && !selectedDirectMessage && activePanel === 'none' }" data-testid="app-shell">
      <aside id="nav-sidebar" class="sidebar" :class="{ 'is-open': navOpen }" :role="modalDrawer === 'nav' ? 'dialog' : undefined" :aria-modal="modalDrawer === 'nav' ? 'true' : undefined" aria-label="Навигация гильдии" data-testid="nav-sidebar">
        <button class="guild-header" type="button" :aria-expanded="activePanel === 'admin'" @click="requestGuildPanel"><img class="guild-mark" src="/brand.png" alt=""><span class="guild-header-copy"><GuildName id="app-title" /><small v-if="guildMemberCount !== null" class="guild-member-count">{{ guildMemberCount }} {{ guildMemberCount === 1 ? 'участник' : guildMemberCount < 5 ? 'участника' : 'участников' }}</small></span><span class="guild-chevron" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="m8 10 4 4 4-4" /></svg></span></button>
        <button v-if="navOpen" class="mobile-nav-close" type="button" aria-label="Закрыть навигацию" @click="toggleNavigation"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg></button>
        <div class="nav-drawer" tabindex="-1">
          <SearchLauncher :active="activePanel === 'search'" @open="requestPanel('search')" @close="activePanel = 'none'" />
          <WorkspaceSidebarTabs class="sidebar-tabs" :active="sidebarSection" @select="sidebarSection = $event" />
          <div class="nav-content">
          <ConnectionStatus :chat="realtimeStore.state" :voice="voiceConnection.state" :roster-available="voiceRoster.channels.value !== null && !voiceRoster.error.value" :last-updated-at="voiceRoster.lastUpdatedAt.value" :roster-retained="voiceRoster.channels.value !== null" @retry-chat="realtimeStore.reconnect()" @retry-roster="voiceRoster.reconnect()" />
          <template v-if="sidebarSection === 'channels'">
            <p v-if="topologyStore.loading" class="state" aria-live="polite">Загружаем каналы…</p>
            <p v-else-if="topologyStore.error" class="state state-error" role="alert">{{ topologyStore.error }} Войдите в аккаунт или повторите попытку.</p>
            <template v-if="topologyStore.topology">
              <ChannelTopologyActions :account-id="props.accountId" :active-voice-channel-id="activeVoiceChannel?.id" :selected-channel-id="selectedChannelId ?? undefined" :topology="topologyStore.topology" :permissions="permissions.snapshot?.permissions ?? { 'channel.text.create': false, 'channel.text.delete': false, 'channel.voice.create': false, 'channel.voice.delete': false, 'category.create': false, 'category.delete': false }" :voice-presence="voiceNavigationPresence" :voice-rosters="voiceRoster.channels.value" @select="requestSelectChannel" @changed="refreshTopology" />
            </template>
            <p v-else-if="!topologyStore.loading && !topologyStore.error" class="state">Каналы пока не созданы.</p>
          </template>
          <DirectMessageNavigation
            v-else
            :direct-messages="directMessageStore.directMessages"
            :error="directMessageStore.error"
            :loading="directMessageStore.loadingNavigation"
            :selected-direct-message-id="directMessageStore.directMessageId ?? undefined"
            @open="requestOpenDirectMessage"
            @select="requestSelectDirectMessage"
          />
          </div>
        </div>
        <VoiceDock :notice="voiceConnection.disconnectNotice" class="mobile-voice-dock" :activation-mode="voiceActivation.mode" :channel="activeVoiceChannel" :participant-count="voiceConnection.voiceVolumeParticipants.length + 1" :active-session="voiceConnection.active !== null" :error="voiceConnection.error" :deafen-changing="voiceConnection.deafenChanging" :deafened="voiceConnection.deafened"
          :microphone-muted="voiceConnection.microphoneMuted" :microphone-permission-denied="voiceConnection.microphonePermissionDenied" :screen-share-state="voiceConnection.screenState" :connection-quality="voiceConnection.connectionQuality" :ping-ms="voiceConnection.pingMs" :state="voiceConnection.state" @leave="leaveVoice" @start-screen="openScreenShareSetup" @stop-screen="voiceConnection.stopScreen"
          @toggle-deafen="voiceConnection.toggleDeafen" @toggle-microphone="voiceConnection.toggleMicrophone" />
        <WorkspaceUserFooter :online="realtimeStore.state === 'CONNECTED'" :role="props.role" :display-name="profile?.display_name" :avatar-u-r-l="profile?.avatar_url" :account-i-d="profile?.account_id" @open-profile="requestPanel('profile')" @open-settings="requestPanel('audio')" />
      </aside>
      <main id="main-region" class="main" data-testid="main-region">
        <WorkspaceMain :account-id="props.accountId" :active-voice-channel="activeVoiceChannel" :panel="activePanel === 'search' ? 'none' : activePanel" :channel="selectedChannel" :direct-message="selectedDirectMessage" :join-voice="joinVoice" :leave-voice="leaveVoice" :activation-mode="voiceActivation.mode" :start-screen="openScreenShareSetup" :selected-screen-profile="selectedScreenProfile"
          :search-expanded="activePanel === 'search'" :self-display-name="profile?.display_name ?? null" :nav-open="navOpen" :members-open="memberHeaderExpandedState" :show-members="!selectedDirectMessage && activePanel === 'none'" :voice-connection="voiceConnection" :voice-roster="voiceRoster.channels.value?.find((room) => room.channelId === selectedChannel?.id) ?? null" :voice-roster-error="voiceRoster.error.value"
          @return-voice="requestReturnToVoice" @toggle-nav="toggleNavigation" @toggle-members="toggleMembers" @open-search="requestPanel('search')" @close-panel="requestPanel($event)">
          <template #admin>
            <AdminPanel v-if="props.role === 'ADMINISTRATOR'" v-model:section="adminSection" :account-id="props.accountId" :categories="topologyStore.topology?.categories ?? []" :revision="topologyStore.topology?.revision ?? 0" @topology-changed="refreshTopology" />
          </template>
          <template #profile><ProfileSettings ref="profileSettings" :profile="profile" :loading="profileLoading" :load-error="profileError" :logout-busy="logoutBusy" :logout-error="logoutError" @saved="setProfile" @logout="signOut" @session-expired="expireSession" /></template>
          <template #audio>
            <AudioSettings :reset-audio-volumes="voiceConnection.resetAudioVolumes" :volume-warning="voiceConnection.voiceVolumeError" :activation-error="voiceActivation.error" :activation-mode="voiceActivation.mode" :connected="Boolean(voiceConnection.active)" :input-device-id="audioSettings.selectedInput" :input-warning="audioSettings.inputWarning" :input-switching="audioSettings.inputSwitching" :devices="audioSettings.devices" :error="audioSettings.error" :processing="audioSettings.processing"
              :actual-audio-diagnostics="voiceConnection.voiceAudioDiagnostics" :audio-profile-locked="!voiceConnection.canJoin" :processing-diagnostics="voiceConnection.audioProcessingDiagnostics" :microphone-track="voiceConnection.microphoneTrack" :ptt-key="voiceActivation.pttKey" :microphone-shortcut="voiceActivation.microphoneShortcut" :deafen-shortcut="voiceActivation.deafenShortcut" :state="audioSettings.state" @load="loadAudioDevices" @select="selectAudioDevice" @set-activation="voiceActivation.setMode"
              @set-processing="audioSettings.setProcessing($event, voiceConnection.setAudioProcessing)" @set-ptt-key="voiceActivation.setPttKey" @set-shortcut="voiceActivation.setShortcut" @reset-shortcuts="voiceActivation.resetShortcuts" />
          </template>
        </WorkspaceMain>
      </main>
      <WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === 'none'" :open="membersOpen" :active-voice-channel="voiceConnection.state === 'LEAVING' ? null : activeVoiceChannel" :selected-voice-channel="selectedChannel?.kind === 'VOICE' ? selectedChannel : null" :participants="voiceConnection.voiceVolumeParticipants" :presence-resolver="guildPresence.resolve" :role="props.role" :account-i-d="profile?.account_id" :self-name="profile?.display_name ?? null" :self-microphone-muted="voiceConnection.microphoneMuted" :self-microphone-unavailable="voiceConnection.microphonePermissionDenied" :modal="modalDrawer === 'members'" @member-count="guildMemberCount = $event" @open-d-m="requestOpenDirectMessageFromMember" @set-volume="voiceConnection.setParticipantVolume" />
      <aside v-else-if="activePanel === 'search'" id="search-aside-panel" class="members search-aside" :class="{ 'is-open': activePanel === 'search' }" :role="modalDrawer === 'search' ? 'dialog' : undefined" :aria-modal="modalDrawer === 'search' ? 'true' : undefined" aria-label="Поиск сообщений" tabindex="-1" data-testid="search-aside-panel"><WorkspaceSearchPanel @open-channel="selectChannel" @open-direct-message="selectDirectMessage" @close="activePanel = 'none'" /></aside>
      <button v-if="navOpen || membersOpen || activePanel === 'search'" class="drawer-scrim" type="button" aria-label="Закрыть навигацию и участников" @click="requestWorkspaceScrimClose" />
    </div>
    <ScreenShareSetupDialog v-if="screenShareSetupOpen" :initial-profile="voiceConnection.screenProfile ?? selectedScreenProfile" :initial-mode="selectedScreenMode" :updating="voiceConnection.screenState === 'SHARING'" @cancel="screenShareSetupOpen = false" @start="confirmScreenShare" />
    <AdminConfirmation ref="profileExitConfirmation" id="profile-unsaved-exit" title="Несохранённые изменения" confirm-label="Выйти без сохранения" />
  </div>
</template>
