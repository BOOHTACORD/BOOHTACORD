<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, watch } from 'vue'
import SystemWelcomeMessage from '../conversation/system_welcome/SystemWelcomeMessage.vue'
import MessageBody from '../conversation/message_body/MessageBody.vue'
import TextMessageAttachments from '../conversation/TextMessageAttachments.vue'
import { loadMessagePage, type TextMessage } from '../conversation/message_client'
import DirectMessageAttachments from '../direct_message/DirectMessageAttachments.vue'
import { loadDirectMessageHistory, type DirectMessageHistoryItem } from '../direct_message/direct_message_client'
import { useAuthorDirectory } from '../identity/author_directory'
import { createSearchContextController } from './search_context_controller'
import { useContextRead } from './context_timeline/read'
import { capture, restore } from '../conversation/context_position/dom'
import { bindContextHints, useContextHints } from './context_timeline/hints'

const props = defineProps<{ kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; messageId: string; heading?: string; unread?: boolean; active?: boolean; offset?: number }>()
const emit = defineEmits<{ close: []; read: []; viewportChange: [] }>()
const authors = useAuthorDirectory()
const page = (before?: string, at?: string, after?: string) => props.kind === 'CHANNEL'
  ? loadMessagePage(props.conversationId, before, undefined, at, after)
  : loadDirectMessageHistory(props.conversationId, before, undefined, at, after)
const context = createSearchContextController<TextMessage | DirectMessageHistoryItem>(id => page(undefined, id), {
  older: id => page(id), newer: id => page(undefined, undefined, id),
})
const { messages, status, hasNewer, olderCursor, pagingPending, pagingError } = context
const stopHints = bindContextHints(useContextHints(), props, context)
const chronological = computed(() => [...messages.value].reverse())
const { readRoot: root, queueVisibleRead } = useContextRead(props, () => messages.value, () => status.value === 'ready' || status.value === 'deleted', () => emit('read'))
function onScroll(): void { queueVisibleRead(); emit('viewportChange') }
async function load(direction: 'older' | 'newer'): Promise<void> {
  const viewport = root.value?.querySelector<HTMLElement>('.search-context-list') ?? null, position = capture(viewport)
  await (direction === 'older' ? context.loadOlder() : context.loadNewer())
  await nextTick()
  if (position) restore(viewport, position)
  onScroll()
}

watch(() => [props.kind, props.conversationId, props.messageId], () => { void context.open(props.messageId) }, { immediate: true, flush: 'sync' })
watch(messages, (items) => { for (const item of items) void authors.ensure(item.authorId) })
watch(status, (value) => { if (value === 'ready' || value === 'deleted') void nextTick(async () => {
  const messageId = props.messageId
  if (props.offset !== undefined) { await context.loadNewer(); await nextTick() }
  if (props.messageId !== messageId || status.value === 'loading') return
  const anchor = root.value?.querySelector<HTMLElement>('[data-search-anchor]')
  anchor?.scrollIntoView({ block: props.unread ? 'start' : 'center' }); anchor?.focus({ preventScroll: true })
  if (props.offset !== undefined) restore(root.value?.querySelector<HTMLElement>('.search-context-list') ?? null, { id: props.messageId, offset: props.offset })
  onScroll()
}) })
onBeforeUnmount(() => { stopHints(); context.clear() })
</script>

<template>
  <section ref="root" class="search-message-context" aria-labelledby="search-context-title" data-testid="search-message-context">
    <header class="search-context-header">
      <h3 id="search-context-title">{{ props.heading ?? 'Контекст найденного сообщения' }}</h3>
      <button type="button" @click="emit('close')">{{ props.unread ? 'К последним сообщениям' : 'Вернуться к исходной позиции' }}</button>
    </header>
    <p v-if="status === 'loading'" role="status">Открываем сообщение…</p>
    <p v-else-if="status === 'unavailable'" role="alert">Сообщение больше недоступно в этой беседе.</p>
    <p v-else-if="status === 'error'" role="alert">Не удалось открыть сообщение. Беседа могла стать недоступной. <button type="button" @click="context.open(props.messageId)">Повторить</button></p>
    <p v-if="pagingError" role="alert">{{ pagingError }}</p>
    <ol v-if="messages.length" class="search-context-list message-list" aria-label="Контекст сообщения" @scroll.passive="onScroll">
      <li v-if="olderCursor"><button type="button" :disabled="pagingPending" @click="load('older')">Показать предыдущие сообщения</button></li>
      <template v-for="message in chronological" :key="message.id">
      <li v-if="props.unread && message.id === props.messageId" class="unread-divider" role="separator" aria-label="Новые сообщения">Новые сообщения</li>
      <li :data-message-id="message.id" :class="{ 'search-context-target': message.id === props.messageId }" :data-search-anchor="message.id === props.messageId ? '' : undefined" :aria-current="message.id === props.messageId ? 'location' : undefined" :tabindex="message.id === props.messageId ? -1 : undefined">
        <p class="message-meta">{{ authors.displayName(message.authorId) }} · {{ new Date(message.createdAt).toLocaleString('ru-RU') }}</p>
        <p v-if="message.deleted">Сообщение удалено.</p>
        <SystemWelcomeMessage v-else-if="'kind' in message && message.kind === 'SYSTEM_WELCOME'" :author-id="message.authorId" :body="message.body" /><MessageBody v-else :body="message.body" />
        <TextMessageAttachments v-if="props.kind === 'CHANNEL' && !message.deleted" :channel-id="props.conversationId" :attachments="message.attachments" />
        <DirectMessageAttachments v-if="props.kind === 'DIRECT_MESSAGE' && !message.deleted" :direct-message-id="props.conversationId" :attachments="message.attachments" />
      </li>
      </template>
      <li v-if="hasNewer"><button type="button" :disabled="pagingPending" @click="load('newer')">Показать следующие сообщения</button></li>
    </ol>
  </section>
</template>

<style scoped>
.search-message-context { display: flex; flex-direction: column; flex: 1; min-height: 0; }
.search-context-list { overflow-y: auto; min-height: 0; flex: 1; }
.unread-divider { text-align: center; color: var(--accent); border-top: 1px solid currentColor; }
</style>
