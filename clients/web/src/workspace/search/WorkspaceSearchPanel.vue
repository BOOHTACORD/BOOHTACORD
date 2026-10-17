<script setup lang="ts">
import { vActionHint } from '../../shared/action_hint/directive'
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import type { TopologyChannel } from '../../channel/topology_client'
import { useDirectMessageStore } from '../../direct_message/direct_message_store'
import { useTopologyStore } from '../../channel/topology_store'
import { useVoiceNavigationStore } from '../../voice/navigation_store'
import SearchPanel from '../../search/SearchPanel.vue'
import type { SearchMessage } from '../../search/search_messages_client'
import { useSearchTargetStore } from '../../search/search_target_store'
import QuickJumpPanel from '../../search/QuickJumpPanel.vue'
import type { QuickJumpTarget } from '../../search/quick_jump'
import type { MentionInboxItem } from '../../search/mentions_inbox_client'
import { targetForMention } from '../../search/mention_target'
import { createQuickJumpPeople } from '../../search/quick_jump_people/state'
import { quickJumpPeople } from '../../search/quick_jump_people/entries'
import { createQuickJumpOpen } from '../../search/quick_jump_people/open'

const emit = defineEmits<{ openChannel: [channel: TopologyChannel]; openDirectMessage: [id: string]; close: [] }>()
const topologyStore = useTopologyStore(), navigation = useVoiceNavigationStore()
const selectedChannel = computed(() => {
  const target = navigation.selectedSurface
  return target.kind === 'TEXT' || target.kind === 'VOICE'
    ? topologyStore.topology?.categories.flatMap(category => category.channels).find(channel => channel.id === target.channelId) : null
})
const directMessageStore = useDirectMessageStore()
const searchTarget = useSearchTargetStore()
const openError = ref('')
const searchMode = ref<'messages' | 'navigation'>('messages')
let openSequence = 0
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
const currentConversation = computed(() => selectedDirectMessage.value
  ? { id: selectedDirectMessage.value.id, kind: 'DIRECT_MESSAGE' as const, label: selectedDirectMessage.value.otherParticipantDisplayName }
  : selectedChannel.value?.kind === 'TEXT' ? { id: selectedChannel.value.id, kind: 'CHANNEL' as const, label: `#${selectedChannel.value.name}` } : null)
const channelLabels = computed(() => Object.fromEntries((topologyStore.topology?.categories ?? []).flatMap((category) => category.channels.filter((channel) => channel.kind === 'TEXT').map((channel) => [channel.id, `#${channel.name}`]))))
const directMessageLabels = computed(() => Object.fromEntries(directMessageStore.directMessages.map((item) => [item.id, item.otherParticipantDisplayName])))
const navigationChannels = computed(() => topologyStore.topology?.categories.flatMap((category) => category.channels) ?? [])
const people = createQuickJumpPeople()
const navigationPeople = computed(() => quickJumpPeople(directMessageStore.directMessages, people.people.value))
watch(searchMode, mode => { if (mode === 'navigation') void people.refresh() })
const quickJump = createQuickJumpOpen({
  channels: () => navigationChannels.value, refreshChannels: () => topologyStore.refresh(),
  channelError: () => Boolean(topologyStore.error), dialogs: () => directMessageStore.directMessages,
  refreshDialogs: () => directMessageStore.refreshNavigation(), dialogError: () => Boolean(directMessageStore.error),
  channel: channel => emit('openChannel', channel), dialog: id => emit('openDirectMessage', id),
  error: message => { openError.value = message },
})
const navigationStatus = computed(() => topologyStore.loading || directMessageStore.loadingNavigation ? 'Загружаем каналы и людей…' : topologyStore.error || directMessageStore.error ? 'Не удалось обновить список. Повторите попытку.' : !topologyStore.topology ? 'Список каналов пока недоступен.' : '')
async function open(message: SearchMessage): Promise<void> {
  const sequence = ++openSequence
  openError.value = ''
  if (message.kind === 'CHANNEL') {
    let channel = topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === message.channelId && item.kind === 'TEXT')
    if (!channel) { await topologyStore.refresh(); if (sequence !== openSequence) return; channel = topologyStore.topology?.categories.flatMap((category) => category.channels).find((item) => item.id === message.channelId && item.kind === 'TEXT') }
    if (!channel) { openError.value = 'Найденный канал больше недоступен.'; return }
    searchTarget.open({ kind: 'CHANNEL', conversationId: channel.id, messageId: message.id })
    emit('openChannel', channel)
  } else {
    if (!directMessageStore.directMessages.some(({ id }) => id === message.directMessageId)) { await directMessageStore.refreshNavigation(); if (sequence !== openSequence) return }
    if (!directMessageStore.directMessages.some(({ id }) => id === message.directMessageId)) { openError.value = 'Личный диалог больше недоступен.'; return }
    searchTarget.open({ kind: 'DIRECT_MESSAGE', conversationId: message.directMessageId, messageId: message.id })
    emit('openDirectMessage', message.directMessageId)
  }
}
async function openMention(mention: MentionInboxItem): Promise<void> {
  const sequence = ++openSequence
  openError.value = ''
  // Cached metadata does not establish current access or channel kind.
  if (mention.kind === 'CHANNEL') await topologyStore.refresh()
  else await directMessageStore.refreshNavigation()
  if (sequence !== openSequence) return
  const refreshFailed = mention.kind === 'CHANNEL' ? Boolean(topologyStore.error) : Boolean(directMessageStore.error)
  const target = refreshFailed ? null : targetForMention(
    mention,
    navigationChannels.value,
    directMessageStore.directMessages.map(({ id }) => id),
  )
  if (!target) {
    openError.value = mention.kind === 'CHANNEL' ? 'Канал с упоминанием больше недоступен.' : 'Личный диалог больше недоступен.'
    return
  }
  searchTarget.open(target)
  if (target.kind === 'CHANNEL') {
    const channel = navigationChannels.value.find(({ id, kind }) => id === target.conversationId && kind === 'TEXT')
    if (!channel) { openError.value = 'Канал с упоминанием больше недоступен.'; searchTarget.clear(); return }
    emit('openChannel', channel)
  } else {
    emit('openDirectMessage', target.conversationId)
  }
}
async function openQuickJump(entry: QuickJumpTarget): Promise<void> {
  openSequence++
  await quickJump.open(entry)
}
onBeforeUnmount(() => { openSequence++; quickJump.dispose(); people.dispose() })
</script>

<template>
  <div class="workspace-search-modes" role="group" aria-label="Тип поиска">
    <button type="button" :aria-pressed="searchMode === 'messages'" @click="searchMode = 'messages'">Сообщения</button>
    <button type="button" :aria-pressed="searchMode === 'navigation'" @click="searchMode = 'navigation'">Каналы и люди</button>
    <button v-action-hint v-if="searchMode === 'navigation'" class="header-action workspace-search-close" type="button" aria-label="Закрыть поиск" @click="emit('close')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg></button>
  </div>
  <SearchPanel v-show="searchMode === 'messages'" :current-conversation="currentConversation" :channel-labels="channelLabels" :direct-message-labels="directMessageLabels" @open="open" @open-mention="openMention" @close="emit('close')" />
  <QuickJumpPanel v-if="searchMode === 'navigation'" :channels="navigationChannels" :people="navigationPeople" :status="navigationStatus" :people-loading="people.loading.value" :people-error="people.error.value" :has-more="Boolean(people.after.value)" @next="people.next()" @retry="people.after.value ? people.next() : people.refresh()" @select="openQuickJump" />
  <p v-if="openError" class="search-error" role="alert">{{ openError }}</p>
</template>

<style scoped>
.workspace-search-modes { display: flex; gap: 8px; margin: 12px 20px 0; }
.workspace-search-modes button:not(.workspace-search-close) { background: transparent; border: 1px solid var(--gc-border, #363a46); border-radius: 999px; color: inherit; cursor: pointer; min-height: 36px; padding: 6px 12px; }
.workspace-search-modes button[aria-pressed="true"] { background: var(--gc-surface-raised, #20232d); border-color: var(--gc-accent, #6974f5); }
@media (max-width: 600px) { .workspace-search-modes { margin-inline: 16px; } }
</style>
