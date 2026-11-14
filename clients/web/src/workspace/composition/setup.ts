import { computed, ref, watch } from 'vue'
import type { TopologyChannel } from '../../channel/topology_client'
import { buildVoiceNavigationPresence } from '../../channel/voice_navigation_presence'
import { createRosterSocketState } from '../../voice/roster_socket/state'
import { useMessageStore } from '../../conversation/message_store'
import type { useRealtimeStore } from '../../realtime/realtime_store'
import { createWorkspaceRealtime } from '../workspace_realtime'
import type { useWorkspaceVoiceControls } from '../voice_controls'
import { useGuildPresence } from '../../identity/guild_presence'
import { useCurrentProfile } from '../../identity/current_profile'
import { useAuthorDirectoryLifecycle } from '../../identity/author_directory_lifecycle'
import type { AdminSection } from '../../admin/panel/admin_section'
import { usePermissionStore } from '../../authorization/permission_store'
import { useScreenShareSetup } from '../screen_share_setup'
import { useWorkspaceNavigation } from '../workspace_navigation'
import { navigateWithSettingsGuard } from '../settings_exit_guard'
import type { ActionScope } from '../../telemetry/action_scope/scope'
import { bindWorkspaceReady } from '../ready_lifecycle/bind'
import { buildGuildVoicePresence } from '../guild_voice_presence'
import { useSearchTargetStore } from '../../search/search_target_store'
import { useNotificationTap } from '../../notification/remote_push/tap'
import { useServerNotifications } from '../../notification/server_preferences/state'

type Props = { role: 'MEMBER' | 'ADMINISTRATOR'; accountId: string; readiness?: ActionScope }

export function useWorkspaceComposition(props: Props, controls: ReturnType<typeof useWorkspaceVoiceControls>, realtimeStore: ReturnType<typeof useRealtimeStore>, expireSession: () => void) {
  const { activeVoiceChannel, audioSettings, loadAudioDevices, joinVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel: selectWorkspaceChannel, selectDirectMessage: selectWorkspaceDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection } = controls
  const adminSection = ref<AdminSection>('members')
  const { confirmScreenShare, openScreenShareSetup, screenShareSetupOpen, selectedScreenProfile, selectedScreenMode } = useScreenShareSetup(() => voiceConnection.screenState, startScreen, props.accountId)
  const { openSupport, activePanel, closeDrawers, directMessageStore, memberHeaderExpandedState, membersOpen, modalDrawer, navOpen, openDirectMessageFromMember, returnToVoice, selectedDirectMessage, selectChannel, selectDirectMessage, selectOpenedDirectMessage, sidebarSection, toggleMembers, toggleNavigation, togglePanel, voiceStageWide } = useWorkspaceNavigation(props.role, selectedChannel, topologyStore, selectWorkspaceChannel, selectWorkspaceDirectMessage)
  const profileSettings = ref<{ hasUnsavedChanges: boolean } | null>(null)
  const profileExitConfirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
  const messageStore = useMessageStore(), guildPresence = useGuildPresence(), permissions = usePermissionStore()
  const voiceRoster = createRosterSocketState(() => realtimeStore.reconnect())
  const guildVoicePresence = computed(() => buildGuildVoicePresence(voiceRoster.error.value ? null : voiceRoster.channels.value, topologyStore.topology?.categories.flatMap(({ channels }) => channels) ?? []))
  const guildMemberCount = ref<number | null>(null)
  const workspaceRealtime = createWorkspaceRealtime({ topology: topologyStore, messages: messageStore, directMessages: directMessageStore }, realtimeStore, guildPresence, voiceConnection, props.accountId, expireSession, undefined, voiceRoster, channelID => joinVoice(channelID, true, 'listener'))
  watch(() => realtimeStore.state, (state) => { if (state === 'ERROR' || state === 'DISCONNECTED') guildPresence.invalidate() })
  const { profile, profileError, profileLoading, refreshProfile, setProfile } = useCurrentProfile()
  useAuthorDirectoryLifecycle(profile)
  const voiceNavigationPresence = computed(() => buildVoiceNavigationPresence(activeVoiceChannel.value?.id ?? null, profile.value, voiceConnection))
  async function beforeWorkspaceNavigation(action: () => void | Promise<unknown>): Promise<void> {
    const hasUnsavedProfileChanges = activePanel.value === 'profile' && Boolean(profileSettings.value?.hasUnsavedChanges)
    await navigateWithSettingsGuard(hasUnsavedProfileChanges, async () => Boolean(await profileExitConfirmation.value?.ask('Введённое имя или пароль ещё не сохранены. Если уйти, эти данные будут потеряны. Продолжить?')), action)
  }
  function requestSupport(): Promise<void> { return beforeWorkspaceNavigation(openSupport) }
  function requestPanel(panel: 'admin' | 'audio' | 'profile' | 'search'): Promise<void> { return beforeWorkspaceNavigation(() => togglePanel(panel)) }
  function requestGuildPanel(): Promise<void> { return props.role === 'ADMINISTRATOR' ? requestPanel('admin') : Promise.resolve() }
  function requestSelectChannel(channel: TopologyChannel): Promise<void> { return beforeWorkspaceNavigation(() => selectChannel(channel)) }
  function requestSelectDirectMessage(id: string): Promise<void> { return beforeWorkspaceNavigation(() => selectDirectMessage(id)) }
  const remoteNotifications = useServerNotifications()
  const notificationTap = useNotificationTap({ account: props.accountId, ready: () => !!topologyStore.topology, navigate: target => beforeWorkspaceNavigation(async () => {
    if (target.kind === 'DM') {
      await directMessageStore.refreshNavigation()
      if (!directMessageStore.directMessages.some(d => d.id === target.conversation_id)) throw new Error('Диалог больше недоступен.')
      useSearchTargetStore().open({ kind: 'DIRECT_MESSAGE', conversationId: target.conversation_id, messageId: target.message_id })
      await selectDirectMessage(target.conversation_id)
    } else {
      await topologyStore.refresh()
      const channel = topologyStore.topology?.categories.flatMap(c => c.channels).find(c => c.id === target.conversation_id && c.kind === 'TEXT')
      if (!channel) throw new Error('Канал больше недоступен.')
      useSearchTargetStore().open({ kind: 'CHANNEL', conversationId: target.conversation_id, messageId: target.message_id })
      await selectChannel(channel)
    }
  }) })
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
  return { activeVoiceChannel, audioSettings, loadAudioDevices, joinVoice, selectAudioDevice, selectedChannel, selectedChannelId, topologyStore, voiceActivation, adminSection, confirmScreenShare, openScreenShareSetup, screenShareSetupOpen, selectedScreenProfile, selectedScreenMode,
    activePanel, directMessageStore, memberHeaderExpandedState, membersOpen, modalDrawer, navOpen, selectedDirectMessage, selectChannel, selectDirectMessage, sidebarSection, toggleMembers, toggleNavigation, voiceStageWide, profileSettings, profileExitConfirmation,
    voiceRoster, guildVoicePresence, guildPresence, guildMemberCount, permissions, profile, profileError, profileLoading, setProfile, voiceNavigationPresence, requestSupport, requestPanel, requestGuildPanel, requestSelectChannel, requestSelectDirectMessage, remoteNotifications, notificationTap, requestOpenDirectMessage, requestReturnToVoice, requestOpenDirectMessageFromMember, requestWorkspaceScrimClose, refreshTopology }
}
