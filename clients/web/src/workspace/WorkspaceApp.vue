<script setup lang="ts">
import { onMounted, onBeforeUnmount } from 'vue'
import GuildName from '../guild/profile/GuildName.vue'
import ChannelTopologyActions from '../channel/member_topology/ChannelTopologyActions.vue'
import AdminConfirmation from '../channel/AdminConfirmation.vue'
import DirectMessageNavigation from '../direct_message/DirectMessageNavigation.vue'
import ShortcutStatus from '../voice/shortcuts/Status.vue'
import VoiceDock from '../voice/VoiceDock.vue'
import ScreenShareSetupDialog from '../voice/ScreenShareSetupDialog.vue'
import AudioSettings from '../voice/AudioSettings.vue'
import { useRealtimeStore } from '../realtime/realtime_store'
import { bindWorkspaceLogout } from './logout_flow'
import { expireWorkspaceSession } from './session_expiry_media'
import { useWorkspaceVoiceControls } from './voice_controls'
import WorkspaceMain from './WorkspaceMain.vue'
import WorkspaceMembersPanel from './WorkspaceMembersPanel.vue'
import WorkspaceSidebarTabs from './WorkspaceSidebarTabs.vue'
import WorkspaceUserFooter from './WorkspaceUserFooter.vue'
import ProfileSettings from '../identity/ProfileSettings.vue'
import AdminPanel from '../admin/panel/AdminPanel.vue'
import SearchLauncher from '../search/SearchLauncher.vue'
import WorkspaceSearchPanel from './search/WorkspaceSearchPanel.vue'
import ConnectionStatus from './connection_status/Status.vue'
import type { ActionScope } from '../telemetry/action_scope/scope'
import { latestNotificationHint } from '../notification/remote_push/hints'
import { useWorkspaceComposition } from './composition/setup'
const props = defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR'; accountId: string;readiness?:ActionScope }>()
const emit = defineEmits<{ sessionExpired: []; loggedOut: [] }>()
const controls = useWorkspaceVoiceControls(props.accountId)
const { voiceConnection, leaveVoice } = controls
const realtimeStore = useRealtimeStore()
const reportActivity = () => realtimeStore.reportActivity()
const activityEvents = ['pointerdown', 'pointermove', 'keydown', 'touchstart', 'wheel'] as const
onMounted(() => activityEvents.forEach((event) => window.addEventListener(event, reportActivity, { passive: true })))
onBeforeUnmount(() => activityEvents.forEach((event) => window.removeEventListener(event, reportActivity)))
const expireSession = () => expireWorkspaceSession(voiceConnection, () => emit('sessionExpired'))
const { busy: logoutBusy, error: logoutError, signOut } = bindWorkspaceLogout(voiceConnection, leaveVoice, realtimeStore, () => emit('loggedOut'))
const { activeVoiceChannel, audioSettings, loadAudioDevices, joinVoice, selectAudioDevice, selectedChannel, selectedChannelId, topologyStore, voiceActivation, adminSection, confirmScreenShare, openScreenShareSetup, screenShareSetupOpen, selectedScreenProfile, selectedScreenMode,
  activePanel, directMessageStore, memberHeaderExpandedState, membersOpen, modalDrawer, navOpen, selectedDirectMessage, selectChannel, selectDirectMessage, sidebarSection, toggleMembers, toggleNavigation, voiceStageWide, profileSettings, profileExitConfirmation,
  voiceRoster, guildVoicePresence, guildPresence, guildMemberCount, permissions, profile, profileError, profileLoading, setProfile, voiceNavigationPresence, requestSupport, requestPanel, requestGuildPanel, requestSelectChannel, requestSelectDirectMessage, remoteNotifications, notificationTap, requestOpenDirectMessage, requestReturnToVoice, requestOpenDirectMessageFromMember, requestWorkspaceScrimClose, refreshTopology } = useWorkspaceComposition(props, controls, realtimeStore, expireSession)
</script>
<template>
  <div class="app-frame">
    <div v-if="remoteNotifications.hint" role="status" class="state notification-hint">{{ remoteNotifications.hint }} <button type="button" @click="notificationTap.accept(latestNotificationHint());remoteNotifications.hint=''">Открыть</button><button type="button" aria-label="Скрыть уведомление" @click="remoteNotifications.hint=''">Закрыть</button></div>
    <p v-if="notificationTap.error.value" role="status" class="state">{{ notificationTap.error.value }}</p>
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
            <p v-else-if="topologyStore.error" class="state state-error" role="alert">{{ topologyStore.error }}</p>
            <template v-if="topologyStore.topology">
              <ChannelTopologyActions :account-id="props.accountId" :active-voice-channel-id="activeVoiceChannel?.id" :selected-channel-id="selectedChannelId ?? undefined" :topology="topologyStore.topology" :permissions="permissions.snapshot?.permissions ?? { 'channel.text.create': false, 'channel.text.delete': false, 'channel.voice.create': false, 'channel.voice.delete': false, 'category.create': false, 'category.delete': false }" :voice-presence="voiceNavigationPresence" :voice-rosters="voiceRoster.channels.value" @select="requestSelectChannel" @changed="refreshTopology" />
            </template>
            <p v-else-if="!topologyStore.loading && !topologyStore.error" class="state">Каналы пока не созданы.</p>
          </template>
          <DirectMessageNavigation
            v-else
            :direct-messages="directMessageStore.directMessages"
            :support-contact="directMessageStore.supportContact" :support-opening="directMessageStore.supportOpening" :support-notice="directMessageStore.supportNotice" :support-changed="directMessageStore.supportChanged" @support="requestSupport"
            :error="directMessageStore.error"
            :loading="directMessageStore.loadingNavigation"
            :selected-direct-message-id="directMessageStore.directMessageId ?? undefined"
            @open="requestOpenDirectMessage"
            @select="requestSelectDirectMessage"
          />
          </div>
        </div>
        <VoiceDock :notice="voiceConnection.disconnectNotice" class="mobile-voice-dock" :activation-mode="voiceActivation.mode" :touch-ptt-enabled="voiceActivation.touchPttEnabled" :set-touch-ptt-pressed="voiceActivation.setTouchPttPressed" :channel="activeVoiceChannel" :participant-count="voiceConnection.voiceVolumeParticipants.length + 1" :active-session="voiceConnection.active !== null" :error="voiceConnection.error" :deafen-changing="voiceConnection.deafenChanging" :deafened="voiceConnection.deafened" :microphone-allowed="voiceConnection.active?.microphoneAllowed !== false"
          :microphone-muted="voiceConnection.microphoneMuted" :microphone-permission-denied="voiceConnection.microphonePermissionDenied" :screen-share-state="voiceConnection.screenState" :connection-quality="voiceConnection.connectionQuality" :ping-ms="voiceConnection.pingMs" :state="voiceConnection.state" @leave="leaveVoice" @start-screen="openScreenShareSetup" @stop-screen="voiceConnection.stopScreen"
          @toggle-deafen="voiceConnection.toggleDeafen" @toggle-microphone="voiceConnection.toggleMicrophone" />
        <WorkspaceUserFooter :online="realtimeStore.state === 'CONNECTED'" :role="props.role" :display-name="profile?.display_name" :avatar-u-r-l="profile?.avatar_url" :account-i-d="profile?.account_id" @open-support="requestSupport" :support-opening="directMessageStore.supportOpening" @open-profile="requestPanel('profile')" @open-settings="requestPanel('audio')" />
      </aside>
      <main id="main-region" class="main" data-testid="main-region">
        <WorkspaceMain :account-id="props.accountId" :active-voice-channel="activeVoiceChannel" :panel="activePanel === 'search' ? 'none' : activePanel" :channel="selectedChannel" :direct-message="selectedDirectMessage" :join-voice="joinVoice" :leave-voice="leaveVoice" :activation-mode="voiceActivation.mode" :start-screen="openScreenShareSetup" :selected-screen-profile="selectedScreenProfile"
          :self-display-name="profile?.display_name ?? null" :nav-open="navOpen" :members-open="memberHeaderExpandedState" :show-members="!selectedDirectMessage && activePanel === 'none'" :voice-connection="voiceConnection" :voice-roster="voiceRoster.channels.value?.find((room) => room.channelId === selectedChannel?.id) ?? null" :voice-roster-error="voiceRoster.error.value"
          @return-voice="requestReturnToVoice" @toggle-nav="toggleNavigation" @toggle-members="toggleMembers" @close-panel="requestPanel($event)">
          <template #admin>
            <AdminPanel v-if="props.role === 'ADMINISTRATOR'" v-model:section="adminSection" :account-id="props.accountId" :categories="topologyStore.topology?.categories ?? []" :revision="topologyStore.topology?.revision ?? 0" @topology-changed="refreshTopology" />
          </template>
          <template #profile><ProfileSettings ref="profileSettings" :profile="profile" :loading="profileLoading" :load-error="profileError" :logout-busy="logoutBusy" :logout-error="logoutError" @saved="setProfile" @logout="signOut" @session-expired="expireSession" /></template>
          <template #audio>
            <AudioSettings :reset-audio-volumes="voiceConnection.resetAudioVolumes" :volume-warning="voiceConnection.voiceVolumeError" :activation-error="voiceActivation.error" :activation-mode="voiceActivation.mode" :touch-ptt-enabled="voiceActivation.touchPttEnabled" :connected="Boolean(voiceConnection.active)" :input-device-id="audioSettings.selectedInput" :input-warning="audioSettings.inputWarning" :input-switching="audioSettings.inputSwitching" :devices="audioSettings.devices" :error="audioSettings.error" :processing="audioSettings.processing"
              :actual-audio-diagnostics="voiceConnection.voiceAudioDiagnostics" :audio-profile-locked="!voiceConnection.canJoin" :processing-diagnostics="voiceConnection.audioProcessingDiagnostics" :microphone-track="voiceConnection.microphoneTrack" :ptt-key="voiceActivation.pttKey" :microphone-shortcut="voiceActivation.microphoneShortcut" :deafen-shortcut="voiceActivation.deafenShortcut" :state="audioSettings.state" @load="loadAudioDevices" @select="selectAudioDevice" @set-activation="voiceActivation.setMode"
              @set-processing="audioSettings.setProcessing($event, voiceConnection.setAudioProcessing)" @set-ptt-key="voiceActivation.setPttKey" @set-shortcut="voiceActivation.setShortcut" @reset-shortcuts="voiceActivation.resetShortcuts" />
          </template>
        </WorkspaceMain>
      </main>
      <WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === 'none'" :open="membersOpen" :active-voice-channel="voiceConnection.state === 'LEAVING' ? null : activeVoiceChannel" :selected-voice-channel="selectedChannel?.kind === 'VOICE' ? selectedChannel : null" :participants="voiceConnection.voiceVolumeParticipants" :voice-presence="guildVoicePresence" :presence-resolver="guildPresence.resolve" :role="props.role" :account-i-d="profile?.account_id" :self-name="profile?.display_name ?? null" :self-microphone-muted="voiceConnection.microphoneMuted" :self-microphone-unavailable="voiceConnection.microphonePermissionDenied" :modal="modalDrawer === 'members'" @member-count="guildMemberCount = $event" @open-d-m="requestOpenDirectMessageFromMember" @set-volume="voiceConnection.setParticipantVolume" />
      <aside v-else-if="activePanel === 'search'" id="search-aside-panel" class="members search-aside" :class="{ 'is-open': activePanel === 'search' }" :role="modalDrawer === 'search' ? 'dialog' : undefined" :aria-modal="modalDrawer === 'search' ? 'true' : undefined" aria-label="Поиск сообщений" tabindex="-1" data-testid="search-aside-panel"><WorkspaceSearchPanel @open-channel="selectChannel" @open-direct-message="selectDirectMessage" @close="activePanel = 'none'" /></aside>
      <button v-if="navOpen || membersOpen || activePanel === 'search'" class="drawer-scrim" type="button" aria-label="Закрыть навигацию и участников" @click="requestWorkspaceScrimClose" />
    </div>
    <ScreenShareSetupDialog v-if="screenShareSetupOpen" :initial-profile="voiceConnection.screenProfile ?? selectedScreenProfile" :initial-mode="selectedScreenMode" :updating="voiceConnection.screenState === 'SHARING'" @cancel="screenShareSetupOpen = false" @start="confirmScreenShare" />
    <AdminConfirmation ref="profileExitConfirmation" id="profile-unsaved-exit" title="Несохранённые изменения" confirm-label="Выйти без сохранения" />
  </div>
</template>
