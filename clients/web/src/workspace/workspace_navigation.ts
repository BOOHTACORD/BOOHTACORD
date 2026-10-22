import { isSupportPeer } from '../support/contact'
import { computed, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import { useDirectMessageCandidateStore } from '../direct_message/direct_message_candidate_store'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useTopologyStore } from '../channel/topology_store'
import { useMemberHeaderExpanded } from './member_header_expanded'
import { useWorkspaceDrawers } from './useWorkspaceDrawers'
import { clearWorkspaceDrawerHistory } from './workspace_drawer_history'
import {
  clearWorkspaceChannelLocation,
  isWorkspaceChannelLocationHash,
  restoreWorkspaceChannelFromLocation,
  setWorkspaceChannelLocation,
} from './workspace_location'

type Panel = 'none' | 'admin' | 'audio' | 'profile' | 'search'

export function useWorkspaceNavigation(role: 'MEMBER' | 'ADMINISTRATOR', selectedChannel: Readonly<Ref<TopologyChannel | null>>, topologyStore: ReturnType<typeof useTopologyStore>, selectWorkspaceChannel: (channel: TopologyChannel) => void, selectWorkspaceDirectMessage: (id: string) => void) {
  const directMessageStore = useDirectMessageStore()
  const directMessageCandidateStore = useDirectMessageCandidateStore()
  const sidebarSection = ref<'channels' | 'messages'>('channels')
  const activePanel = ref<Panel>('none')
  const { navOpen, membersOpen, modalDrawer, closeDrawers, closeDrawersForNavigation, toggleNavigation, toggleMembers } = useWorkspaceDrawers(activePanel)
  const selectedDirectMessage = computed(() => {
   const item=directMessageStore.directMessages.find(item=>item.id===directMessageStore.directMessageId)
   return item && isSupportPeer(item.otherParticipantId,directMessageStore.supportContact) ? {...item,otherParticipantDisplayName:'Поддержка'} : item??null
  })
  let navigationRevision=0
  let active=true
  onBeforeUnmount(()=>{active=false})
  async function openSupport(): Promise<void> {
   activePanel.value='none';sidebarSection.value='messages'
   const revision=++navigationRevision
   const id=await directMessageStore.openSupport()
   if(active && revision===navigationRevision && sidebarSection.value==='messages' && activePanel.value==='none' && id) selectDirectMessage(id)
  }
  const voiceStageWide = computed(() => selectedChannel.value?.kind === 'VOICE' && !selectedDirectMessage.value && activePanel.value === 'none')
  const memberHeaderExpandedState = useMemberHeaderExpanded(voiceStageWide, membersOpen, closeDrawers)

  function hasTransientWorkspaceView(): boolean {
    return navOpen.value || membersOpen.value || activePanel.value !== 'none'
  }

  function writeChannelLocation(channelId: string): void {
    if (typeof window === 'undefined') return
    const replace = hasTransientWorkspaceView()
    if (replace) clearWorkspaceDrawerHistory(window.history)
    setWorkspaceChannelLocation(window.history, window.location.href, channelId, replace)
  }

  function clearChannelLocation(): void {
    if (typeof window === 'undefined') return
    if (hasTransientWorkspaceView()) clearWorkspaceDrawerHistory(window.history)
    clearWorkspaceChannelLocation(window.history, window.location.href)
  }

  function selectChannel(channel: TopologyChannel, updateLocation = true): void {
    navigationRevision++
    if (updateLocation) writeChannelLocation(channel.id)
    closeDrawersForNavigation()
    activePanel.value = 'none'
    sidebarSection.value = 'channels'
    directMessageStore.close()
    selectWorkspaceChannel(channel)
  }

  function returnToVoice(channelId: string): void { const channel = topologyStore.topology?.categories.flatMap(({ channels }) => channels).find(({ id, kind }) => id === channelId && kind === 'VOICE'); if (channel) selectChannel(channel) }

  function selectDirectMessage(id: string): void {
    navigationRevision++
    closeDrawersForNavigation()
    clearChannelLocation()
    activePanel.value = 'none'
    sidebarSection.value = 'messages'
    selectWorkspaceDirectMessage(id)
    void directMessageStore.open(id)
  }

  async function selectOpenedDirectMessage(id: string): Promise<void> { await directMessageStore.refreshNavigation(); selectDirectMessage(id) }
  async function openDirectMessageFromMember(userID: string): Promise<void> {
    navigationRevision++
    closeDrawersForNavigation(); activePanel.value = 'none'; sidebarSection.value = 'messages'; directMessageStore.close()
    const directMessageID = await directMessageCandidateStore.open(userID)
    if (directMessageID) await selectOpenedDirectMessage(directMessageID)
    else directMessageStore.error = directMessageCandidateStore.error ?? 'Не удалось открыть личное сообщение.'
  }

  function restoreChannelFromLocation(): void {
    if (typeof window === 'undefined' || !isWorkspaceChannelLocationHash(window.location.hash)) return
    restoreWorkspaceChannelFromLocation(
      window.location.hash,
      topologyStore.topology,
      window.history,
      window.location.href,
      (channel) => {
        if (selectedChannel.value?.id !== channel.id) selectChannel(channel, false)
      },
    )
  }

  watch(
    () => [topologyStore.topology, selectedChannel.value] as const,
    ([topology, channel]) => {
      if (typeof window === 'undefined' || !topology) return
      if (isWorkspaceChannelLocationHash(window.location.hash)) {
        restoreChannelFromLocation()
      } else if (!window.location.hash && channel) {
        setWorkspaceChannelLocation(window.history, window.location.href, channel.id, true)
      }
    },
    { immediate: true, flush: 'post' },
  )

  onMounted(() => window.addEventListener('popstate', restoreChannelFromLocation))
  onBeforeUnmount(() => window.removeEventListener('popstate', restoreChannelFromLocation))

  function togglePanel(panel: Exclude<Panel, 'none'>): void { navigationRevision++; closeDrawersForNavigation(); activePanel.value = activePanel.value === panel ? 'none' : panel }
  function openGuildPanel(): void { if (role === 'ADMINISTRATOR') togglePanel('admin') }
  return { openSupport, activePanel, closeDrawers, directMessageStore, memberHeaderExpandedState, membersOpen, modalDrawer, navOpen, openDirectMessageFromMember, openGuildPanel, returnToVoice, selectedDirectMessage, selectChannel, selectDirectMessage, selectOpenedDirectMessage, sidebarSection, toggleMembers, toggleNavigation, togglePanel, voiceStageWide }
}
