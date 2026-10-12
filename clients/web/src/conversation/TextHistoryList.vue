<script setup lang="ts">
import { ref } from 'vue'
import type { CurrentSession } from '../identity/current_session'
import MessageItem from './MessageItem.vue'
import type { TextMessage } from './message_client'
import { useTextHistoryList } from './history_window/use_text_history_list'

const props = defineProps<{ channelId: string; session: CurrentSession | null }>()
const emit = defineEmits<{ reply: [message: TextMessage]; retry: [message: TextMessage]; replyContext: [messageId: string]; viewportChange: [] }>()
const list = ref<HTMLOListElement | null>(null)
const { store, timeline, announcement, jumpCount, historyWindow, onScroll, jumpToLatest, openReplyContext, replyPreview, loadOlder, loadNewer } = useTextHistoryList(
  props, { viewportChange: () => emit('viewportChange'), replyContext: (id) => emit('replyContext', id) }, list)
</script>

<template>
  <div class="message-history-wrap">
  <p class="gc-sr-only" role="status" aria-atomic="true">{{ announcement }}</p>
  <button v-if="jumpCount" class="message-jump-latest" type="button" @click="jumpToLatest">К новым сообщениям ({{ jumpCount }})</button>
  <ol ref="list" class="messages message-list" :class="{ 'message-list--virtual': true }" role="log" aria-live="off" aria-label="История сообщений" @scroll.passive="onScroll" @focusin="historyWindow.pinFocused" @focusout="historyWindow.releaseFocus">
    <li role="presentation" v-if="store.nextCursor || store.olderError" class="virtual-history-control" data-history-control>
      <button v-if="store.nextCursor" type="button" :disabled="store.olderLoading" @click="loadOlder">{{ store.olderLoading ? 'Загружаем старые сообщения…' : 'Показать предыдущие сообщения' }}</button>
      <span v-if="store.olderError" class="state state-error" role="alert">{{ store.olderError }} <button type="button" :disabled="store.olderLoading" @click="loadOlder">Повторить</button></span>
    </li>
    <li role="presentation" v-if="historyWindow.range.value.start" class="virtual-spacer" aria-hidden="true" :style="{ height: `${historyWindow.topSpacer.value}px` }" />
    <li role="presentation" v-for="entry in historyWindow.renderedRows.value" :key="entry.key" :data-virtual-key="entry.key" :data-message-id="entry.kind === 'message' ? entry.message.id : undefined"
      :class="entry.kind === 'date' ? 'history-date' : ['virtual-row', { 'grouped-message': entry.grouped }]" :style="historyWindow.rowStyle(entry)">
      <template v-if="entry.kind === 'date'"><span v-if="entry.showStart" class="history-start" role="status" aria-label="Это начало истории.">Начало</span><time :datetime="entry.dateTime">{{ entry.dateLabel }}</time></template>
      <MessageItem v-else
        :message="entry.message"
        :grouped="entry.grouped"
        :reply-preview="replyPreview(entry.message)"
        :can-edit="entry.message.kind !== 'SYSTEM_WELCOME' && session?.accountId === entry.message.authorId"
        :can-delete="session?.role === 'ADMINISTRATOR' || entry.message.kind !== 'SYSTEM_WELCOME' && session?.accountId === entry.message.authorId"
        :retry-disabled="store.sending"
        :edit-message="(body, ids, revision) => store.editWithResult(entry.message.id, body, revision, undefined, ids)"
        :refresh-message="() => store.refreshMessage(entry.message.id)"
        @remove="store.remove(entry.message.id)"
        @reply="emit('reply', entry.message)"
        @reply-context="openReplyContext"
        @retry="emit('retry', entry.message)"
        @edit-state="historyWindow.setEditing(entry.message.id, $event)"
      />
    </li>
    <li role="presentation" v-if="historyWindow.range.value.end < timeline.length" class="virtual-spacer" aria-hidden="true" :style="{ height: `${historyWindow.bottomSpacer.value}px` }" />
    <li role="presentation" v-if="store.newerCursor || store.newerError" class="virtual-history-control" data-history-control>
      <button v-if="store.newerCursor" type="button" :disabled="store.newerLoading" @click="loadNewer">{{ store.newerLoading ? 'Загружаем новые сообщения…' : 'Показать следующие сообщения' }}</button>
      <span v-if="store.newerError" class="state state-error" role="alert">{{ store.newerError }} <button type="button" :disabled="store.newerLoading" @click="loadNewer">Повторить</button></span>
    </li>
    <li role="presentation" v-if="!store.messages.length && !store.loading" class="state">Сообщений пока нет.</li>
  </ol>
  </div>
</template>
