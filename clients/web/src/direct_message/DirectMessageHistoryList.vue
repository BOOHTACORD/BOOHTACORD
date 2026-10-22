<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import MessageItem from '../conversation/MessageItem.vue'
import { chronologicalDatedMessages } from '../conversation/history_dates'
import { createMessageLogAnnouncer } from '../conversation/message_log_announcement'
import { groupChronologicalMessages } from '../conversation/message_grouping'
import { isHistoryNearBottom, newestServerMessageId, newServerMessageCount } from '../conversation/new_message_jump'
import { useAuthorDirectory } from '../identity/author_directory'
import type { CurrentSession } from '../identity/current_session'
import type { DirectMessageHistoryItem } from './direct_message_client'
import { useDirectMessageStore } from './direct_message_store'
import { navigateToReplyTarget } from '../conversation/reply_context_navigation'
import { useDirectMessageScrollAnchor } from './history_scroll_anchor'

const props = defineProps<{ directMessageId: string; session: CurrentSession | null; otherParticipantId: string; otherParticipantDisplayName: string; emptyText?: string }>()
const emit = defineEmits<{ reply: [message: DirectMessageHistoryItem]; retry: [message: DirectMessageHistoryItem]; replyContext: [messageId: string]; viewportChange: [] }>()
const store = useDirectMessageStore()
const authors = useAuthorDirectory()
const list = ref<HTMLOListElement | null>(null)
const scrollAnchor = useDirectMessageScrollAnchor(list)
const chronologicalMessages = computed(() => groupChronologicalMessages(chronologicalDatedMessages(store.messages)))
const announceNew = createMessageLogAnnouncer()
const announcement = ref('')
const jumpCount = ref(0)
const latestServerId = computed(() => newestServerMessageId(store.messages))
let announcementVersion = 0

watch([() => props.directMessageId, () => store.directMessageId, () => store.historyLoaded, () => store.messages, () => props.session?.accountId], async () => {
  const text = announceNew({ conversationId: props.directMessageId, loaded: store.historyLoaded && store.directMessageId === props.directMessageId,
    active: typeof document !== 'undefined' && document.visibilityState === 'visible', ownId: props.session?.accountId ?? '',
    messages: store.messages, displayName: (id) => authors.displayName(id) })
  const version = ++announcementVersion
  announcement.value = ''
  if (!text) return
  await nextTick()
  if (version === announcementVersion) announcement.value = text
}, { immediate: true, flush: 'post' })
onMounted(() => { if (list.value) list.value.scrollTop = list.value.scrollHeight; scrollAnchor.capture(); emit('viewportChange') })
watch(() => props.directMessageId, async () => { jumpCount.value = 0; await nextTick(); if (list.value) list.value.scrollTop = list.value.scrollHeight; scrollAnchor.capture(); emit('viewportChange') })
watch([() => store.historyLoaded, latestServerId], async ([loaded, newest], [wasLoaded, previous]) => {
  const viewport = list.value
  if (!newest || !viewport || store.directMessageId !== props.directMessageId) return
  const nearBottom = isHistoryNearBottom(viewport)
  const added = newServerMessageCount(store.messages, previous, wasLoaded)
  await nextTick()
  if (nearBottom) { viewport.scrollTop = viewport.scrollHeight; scrollAnchor.capture(); jumpCount.value = 0 }
  else if (loaded) jumpCount.value += added
  emit('viewportChange')
})

function onScroll(): void { scrollAnchor.onScroll(); if (isHistoryNearBottom(list.value)) jumpCount.value = 0; emit('viewportChange') }
function jumpToLatest(): void { if (!list.value) return; list.value.scrollTop = list.value.scrollHeight; scrollAnchor.capture(); jumpCount.value = 0; emit('viewportChange') }
function openReplyContext(messageId: string): void {
  navigateToReplyTarget(list.value, messageId, () => emit('replyContext', messageId))
}
watch(() => store.messages, (messages) => {
  for (const message of messages) if (message.replyPreview) void authors.ensure(message.replyPreview.authorId)
}, { immediate: true })

function replyPreview(message: DirectMessageHistoryItem): string | undefined {
  const preview = message.replyPreview
  if (!preview) return undefined
  return preview.deleted ? 'Сообщение удалено' : `${authors.displayName(preview.authorId)}: ${preview.body.slice(0, 140)}`
}

async function loadOlder(): Promise<void> {
  const viewport = list.value
  const anchor = scrollAnchor.capture()
  const directMessageId = props.directMessageId
  if (!await store.loadOlder()) return
  await nextTick()
  if (!viewport || directMessageId !== props.directMessageId) return
  scrollAnchor.restore(anchor)
  emit('viewportChange')
}
</script>

<template>
  <div class="message-history-wrap">
  <p class="gc-sr-only" role="status" aria-atomic="true">{{ announcement }}</p>
  <button v-if="jumpCount" class="message-jump-latest" type="button" @click="jumpToLatest">К новым сообщениям ({{ jumpCount }})</button>
  <ol ref="list" class="messages message-list" role="log" aria-live="off" aria-label="История личного диалога" @scroll.passive="onScroll">
    <li role="presentation" v-if="store.nextCursor" class="message-actions"><button class="history-load-control" type="button" :disabled="store.olderLoading" :aria-busy="store.olderLoading" :aria-label="store.olderLoading ? 'Загружаем старые сообщения…' : 'Показать предыдущие сообщения'" @click="loadOlder">
      <span aria-hidden="true" :class="{ 'history-load-caption-hidden': store.olderLoading }">Показать предыдущие сообщения</span>
      <span aria-hidden="true" :class="{ 'history-load-caption-hidden': !store.olderLoading }">Загружаем старые сообщения…</span>
    </button></li>
    <li v-if="store.olderError" class="state state-error" role="alert">{{ store.olderError }} <button type="button" :disabled="store.olderLoading" @click="loadOlder">Повторить</button></li>
    <template v-for="(entry, index) in chronologicalMessages" :key="entry.message.id">
    <li role="presentation" v-if="entry.dateLabel" class="history-date"><span v-if="store.historyLoaded && !store.nextCursor && index === 0" class="history-start" role="status" aria-label="Это начало истории.">Начало</span><time :datetime="entry.dateTime">{{ entry.dateLabel }}</time></li>
    <li role="presentation" :data-message-id="entry.message.id" :class="{ 'grouped-message': entry.grouped }">
      <MessageItem
        :message="entry.message"
        :grouped="entry.grouped"
        :reply-preview="replyPreview(entry.message)"
        :can-edit="session?.accountId === entry.message.authorId"
        :can-delete="session?.accountId === entry.message.authorId"
        :retry-disabled="store.sending"
        :mention-recipient="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }"
        :edit-message="(body, ids, revision) => store.editWithResult(entry.message.id, body, revision, undefined, ids)"
        :refresh-message="() => store.refreshMessage(entry.message.id)"
        @remove="store.remove(entry.message.id)"
        @reply="emit('reply', entry.message)"
        @reply-context="openReplyContext"
        @retry="emit('retry', entry.message)"
      />
    </li>
    </template>
    <li role="presentation" v-if="store.historyLoaded && !store.error && !store.messages.length && !store.loadingHistory" class="state">{{ props.emptyText ?? 'Сообщений пока нет.' }}</li>
  </ol>
  </div>
</template>
