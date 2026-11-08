<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useTopologyStore } from '../channel/topology_store'
import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import type { TextMessage } from './message_client'
import { useMessageStore } from './message_store'
import TextHistoryList from './TextHistoryList.vue'
import TextMessageAttachmentPicker from './TextMessageAttachmentPicker.vue'
import MentionPicker from './MentionPicker.vue'
import MentionAutocomplete from './MentionAutocomplete.vue'
import EmojiPicker from './EmojiPicker.vue'
import { useComposerInput } from './composer_input/controller'
import ConversationOverflowMenu from './ConversationOverflowMenu.vue'
import ConversationFilesPanel from './files_panel/ConversationFilesPanel.vue'
import type { TextAttachmentUpload } from './text_attachment_upload_client'
import { advanceTextReadIfVisible } from './text_read_gate'
import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import { useSavedComposer } from './use_saved_composer'
import { submitOnComposerEnter } from './composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'
import { useScopedSend } from './use_scoped_send'
import type { Position } from './context_position/dom'
import { useContextPosition } from './context_position/return'
import { useVisibleRead } from './use_visible_read'

const props = defineProps<{ accountId: string; active: boolean; channelId: string; channelName: string; channelDescription?: string; navOpen: boolean; membersOpen: boolean; showMembers: boolean }>()
const emit = defineEmits<{ toggleNav: []; toggleMembers: [] }>()
const store = useMessageStore()
const topology = useTopologyStore()
const searchTarget = useSearchTargetStore()
const filesOpen = ref(false)
const contextTarget = computed(() => searchTarget.target?.kind === 'CHANNEL' && searchTarget.target.conversationId === props.channelId ? searchTarget.target : null)
const historyList = ref<{ showMessage: (messageId: string) => Promise<boolean>; restoreMessagePosition: (position: Position) => Promise<boolean>; beginTargetNavigation: () => void; endTargetNavigation: () => void } | null>(null)
const searchNavigationError = ref('')
const replyContextTarget = ref<string | null>(null)
const firstUnread = computed(() => topology.topology?.categories.flatMap(({ channels }) => channels).find(({ id }) => id === props.channelId)?.firstUnreadMessageId)
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useSavedComposer<TextMessage, TextAttachmentUpload>(props.accountId, 'CHANNEL', () => props.channelId)
const { draft, replyTarget, attachments, mentionUserIds, attachmentPending, attachmentClearToken } = composer
const overflow = ref<{ focus: () => void } | null>(null)
const composerTextarea = ref<HTMLTextAreaElement | null>(null)
const attachmentPicker = ref<{ addPastedFiles: (files: File[]) => void } | null>(null)
const emojiPicker = ref<{ show: () => Promise<void> } | null>(null)
const { readRoot, queueVisibleRead } = useVisibleRead({
  conversationId: () => props.channelId, loadedConversationId: () => store.channelId, messages: () => store.messages,
  firstUnreadMessageId: () => firstUnread.value,
  canRead: () => props.active && Boolean(topology.topology) && !filesOpen.value && !contextTarget.value && !replyContextTarget.value,
  advance: (id, messageId) => advanceTextReadIfVisible({ activeChannelId: store.channelId, renderedChannelId: id,
    newestDisplayedMessageId: messageId, visibilityState: document.visibilityState }),
  refreshCounters: () => { void topology.refresh() },
})
const contextOpen = () => Boolean(filesOpen.value || replyContextTarget.value)
const { save: savePosition } = useContextPosition(props.accountId, 'CHANNEL', () => props.channelId, readRoot, contextOpen, () => store.historyLoaded && store.channelId === props.channelId, restorePosition)
async function restorePosition(position: Position): Promise<void> {
  const channelId = props.channelId
  const list = historyList.value
  list?.beginTargetNavigation()
  try {
    if (!await store.openAround(position.id) || props.channelId !== channelId) return
    await store.loadNewer()
    await nextTick()
    if (props.channelId !== channelId) return
    await list?.restoreMessagePosition(position)
  } finally {
    await nextTick()
    list?.endTargetNavigation()
  }
}
function onViewportChange(): void { savePosition(); queueVisibleRead() }
let handledTargetKey = ''
watch([contextTarget, () => store.channelId, () => store.historyLoaded], async ([target, loadedId, loaded]) => {
  if (!target || loadedId !== props.channelId || !loaded) return
  const key = `${target.conversationId}:${target.messageId}`
  if (handledTargetKey === key) return
  handledTargetKey = key
  filesOpen.value = false; replyContextTarget.value = null; searchNavigationError.value = ''
  historyList.value?.beginTargetNavigation()
  try {
    if (!await store.openAround(target.messageId) || contextTarget.value?.messageId !== target.messageId) {
      if (contextTarget.value?.messageId === target.messageId) {
        searchNavigationError.value = 'Не удалось открыть найденное сообщение. Попробуйте ещё раз.'
        searchTarget.clear()
      }
      return
    }
    await store.loadNewer()
    await nextTick()
    const shown = await historyList.value?.showMessage(target.messageId)
    if (contextTarget.value?.messageId !== target.messageId) return
    if (shown) searchTarget.clear()
    else { searchNavigationError.value = 'Не удалось найти сообщение в истории канала.'; searchTarget.clear() }
  } finally {
    await nextTick(); await nextTick()
    historyList.value?.endTargetNavigation()
  }
}, { flush: 'post' })
watch(() => searchTarget.target, (target) => { if (!target) handledTargetKey = '' })
watch(() => props.channelId, (channelId) => {
  replyContextTarget.value = null
  void store.open(channelId)
  void loadSession()
}, { immediate: true })
onBeforeUnmount(() => searchTarget.clearFor('CHANNEL', props.channelId))

const { send, retry } = useScopedSend<TextMessage, TextAttachmentUpload, TextMessage>(
  props.accountId, 'CHANNEL', () => props.channelId, composer,
  () => !attachmentPending.value && store.channelId === props.channelId,
  () => store.send(draft.value, undefined, undefined, replyTarget.value?.id, attachments.value, session.value?.accountId, mentionUserIds.value),
  (id) => store.retry(id),
)

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}
const { addEmoji, insertMobileMention, onComposerPaste, onDragOver, onDrop } = useComposerInput(draft, composerTextarea, attachmentPicker, () => props.active && !store.sending)
</script>

<template>
  <section ref="readRoot" class="text-conversation" aria-labelledby="conversation-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M10 3 8 21M16 3l-2 18M4 9h16M3 15h16" /></svg></span>
      <div class="main-title">
        <h2 id="conversation-title" :title="channelName">{{ channelName }}</h2><small v-if="channelDescription" :title="channelDescription">{{ channelDescription }}</small>
      </div>
      <WorkspaceHeaderActions :members-expanded="props.membersOpen" :nav-expanded="props.navOpen" :show-members="props.showMembers" @toggle-members="emit('toggleMembers')" @toggle-navigation="emit('toggleNav')"><template #overflow><ConversationOverflowMenu ref="overflow" :show-members="props.showMembers" :members-open="props.membersOpen" show-files @toggle-members="emit('toggleMembers')" @files="filesOpen = true" /></template></WorkspaceHeaderActions>
    </header>
    <p v-if="store.loading" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" id="text-conversation-error" class="state state-error" role="alert">{{ store.error }} <span v-if="store.historyLoaded">Показанная история может быть устаревшей.</span> <button v-if="store.retryableError" type="button" @click="store.refresh()">Повторить загрузку</button></p>
    <p v-if="searchNavigationError" class="state state-error" role="alert">{{ searchNavigationError }}</p>
    <ConversationFilesPanel v-if="filesOpen" kind="CHANNEL" :conversation-id="props.channelId" :deleted-message-ids="store.deletedMessageIds" @open-message="filesOpen = false; searchTarget.open({ kind: 'CHANNEL', conversationId: props.channelId, messageId: $event })" @close="filesOpen = false; void nextTick(() => overflow?.focus())" />
    <SearchMessageContext v-else-if="replyContextTarget" kind="CHANNEL" :conversation-id="props.channelId" :message-id="replyContextTarget" heading="Контекст ответа" @close="replyContextTarget = null" />
    <TextHistoryList ref="historyList" v-show="!contextOpen()" :channel-id="props.channelId" :session="session" @reply="replyTarget = $event" @reply-context="replyContextTarget = $event" @retry="retry" @viewport-change="onViewportChange" />
    <div class="composer-wrap">
      <p v-if="replyTarget" class="reply-target"><span class="reply-target-icon" aria-hidden="true">↶</span><span>Ответ <strong>{{ authors.displayName(replyTarget.authorId) }}</strong> · {{ replyTarget.body }}</span><button type="button" aria-label="Отменить ответ" @click="replyTarget = null">×</button></p>
      <MentionAutocomplete v-model="draft" v-model:mention-user-ids="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" />
      <form class="message-composer composer" @submit.prevent="send" @dragover="onDragOver" @drop="onDrop">
        <TextMessageAttachmentPicker ref="attachmentPicker" :channel-id="props.channelId" :initial-attachments="attachments" :disabled="store.sending"
          :clear-token="attachmentClearToken" @change="attachments = $event" @pending="attachmentPending = $event" @mention="insertMobileMention" @emoji="emojiPicker?.show()" />
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" quick @activate="insertMobileMention" />
        <label class="gc-sr-only" for="message-body">Сообщение</label>
        <textarea id="message-body" ref="composerTextarea" v-model="draft" rows="1" :disabled="store.sending" :aria-describedby="store.error ? 'text-conversation-error text-composer-help' : 'text-composer-help'" :placeholder="`Написать в #${channelName}`" @keydown="submitOnComposerEnter($event, send)" @paste="onComposerPaste" />
        <EmojiPicker ref="emojiPicker" :disabled="store.sending" @select="addEmoji" />
        <button v-action-hint class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || (!draft && attachments.length === 0)"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m22 2-7 20-4-9-9-4 20-7ZM22 2 11 13"/></svg></button>
      </form>
      <div class="composer-helper"><p id="text-composer-help" class="composer-shortcut-help">Enter — отправить · Shift + Enter — новая строка</p><p class="composer-helper__limit">Файлы до 25 МБ</p></div>
    </div>
  </section>
</template>
