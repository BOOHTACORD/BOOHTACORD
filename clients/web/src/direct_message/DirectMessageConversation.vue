<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { loadCurrentSession, type CurrentSession } from '../identity/current_session'
import { useAuthorDirectory } from '../identity/author_directory'
import MentionPicker from '../conversation/MentionPicker.vue'
import MentionAutocomplete from '../conversation/MentionAutocomplete.vue'
import EmojiPicker from '../conversation/EmojiPicker.vue'
import { useComposerInput } from '../conversation/composer_input/controller'
import ConversationOverflowMenu from '../conversation/ConversationOverflowMenu.vue'
import ConversationFilesPanel from '../conversation/files_panel/ConversationFilesPanel.vue'
import type { TextMessageAttachment } from '../conversation/message_client'
import DirectMessageAttachmentPicker from './DirectMessageAttachmentPicker.vue'
import DirectMessageHistoryList from './DirectMessageHistoryList.vue'
import DirectMessageSearch from './DirectMessageSearch.vue'
import type { DirectMessageHistoryItem } from './direct_message_client'
import { advanceReadIfVisible } from './direct_message_read_gate'
import { useDirectMessageStore } from './direct_message_store'
import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import { useSavedComposer } from '../conversation/use_saved_composer'
import { submitOnComposerEnter } from '../conversation/composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'
import { useUnreadBoundary } from '../conversation/use_unread_boundary'
import { useScopedSend } from '../conversation/use_scoped_send'
import type { Position } from '../conversation/context_position/dom'
import { useContextPosition } from '../conversation/context_position/return'
import { useVisibleRead } from '../conversation/use_visible_read'
const props = defineProps<{ accountId: string; active: boolean; directMessageId: string; otherParticipantId: string; otherParticipantDisplayName: string; navOpen: boolean }>()
const emit = defineEmits<{ toggleNav: [] }>()
const store = useDirectMessageStore()
const firstUnread = computed(() => store.directMessages.find(({ id }) => id === props.directMessageId)?.firstUnreadMessageId)
const { unreadBoundary, unreadContextOpen, readUnlocked, showUnread, continueAtLatest } = useUnreadBoundary(() => props.directMessageId, firstUnread, () => { void showLatest().then(queueVisibleRead) })
const searchTarget = useSearchTargetStore()
const filesOpen = ref(false)
const contextTarget = computed(() => searchTarget.target?.kind === 'DIRECT_MESSAGE' && searchTarget.target.conversationId === props.directMessageId ? searchTarget.target : null)
const replyContextTarget = ref<string | null>(null)
const restored = ref<Position | null>(null)
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useSavedComposer<DirectMessageHistoryItem, TextMessageAttachment>(props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId)
const { draft, replyTarget, mentionUserIds, attachments, attachmentPending, attachmentClearToken } = composer
const searchOpen = ref(false)
const searchMounted = ref(false)
const searchTrigger = ref<HTMLButtonElement | null>(null)
const composerTextarea = ref<HTMLTextAreaElement | null>(null)
const attachmentPicker = ref<{ addPastedFiles: (files: File[]) => void } | null>(null)
const emojiPicker = ref<{ show: () => Promise<void> } | null>(null)
const { readRoot, queueVisibleRead } = useVisibleRead({
  conversationId: () => props.directMessageId, loadedConversationId: () => store.directMessageId, messages: () => store.messages,
  canRead: () => props.active && store.directMessages.some(({ id }) => id === props.directMessageId) && !filesOpen.value && !contextTarget.value && !replyContextTarget.value && !unreadContextOpen.value && !restored.value && (!unreadBoundary.value || readUnlocked.value),
  advance: (id, messageId) => advanceReadIfVisible({ activeDirectMessageId: store.directMessageId,
    renderedDirectMessageId: id, newestDisplayedMessageId: messageId, visibilityState: document.visibilityState }),
  refreshCounters: () => { void store.refreshNavigation() },
})

const contextOpen = () => Boolean(filesOpen.value || contextTarget.value || replyContextTarget.value || unreadContextOpen.value || restored.value)
const { save: savePosition, showLatest } = useContextPosition(props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId, readRoot, contextOpen, () => store.historyLoaded && store.directMessageId === props.directMessageId, restored)
function onViewportChange(): void { savePosition(); queueVisibleRead() }
const { send, retry } = useScopedSend<DirectMessageHistoryItem, TextMessageAttachment, DirectMessageHistoryItem>(
  props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId, composer,
  () => !attachmentPending.value && store.directMessageId === props.directMessageId,
  () => store.send(draft.value, undefined, undefined, replyTarget.value?.id, session.value?.accountId, mentionUserIds.value, attachments.value),
  (id) => store.retry(id),
)

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

const { addEmoji, insertMobileMention, onComposerPaste, onDragOver, onDrop } = useComposerInput(draft, composerTextarea, attachmentPicker, () => props.active && !store.sending)
function openSearch(): void { searchMounted.value = true; searchOpen.value = true }
function toggleSearch(): void { searchOpen.value ? closeSearch() : openSearch() }
function closeSearch(): void { searchOpen.value = false; void nextTick(() => searchTrigger.value?.focus()) }


onMounted(() => {
  void loadSession()
})
watch(() => props.directMessageId, () => { replyContextTarget.value = null })
onBeforeUnmount(() => searchTarget.clearFor('DIRECT_MESSAGE', props.directMessageId))
</script>

<template>
  <section ref="readRoot" class="direct-message-conversation" aria-labelledby="direct-message-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol conversation-symbol--person" aria-hidden="true">@</span>
      <div class="main-title">
        <h2 id="direct-message-title">{{ props.otherParticipantDisplayName }}</h2>
        <small>Личный диалог</small>
      </div>
      <WorkspaceHeaderActions :members-expanded="false" :nav-expanded="props.navOpen" :show-members="false" @toggle-navigation="emit('toggleNav')"><button v-action-hint ref="searchTrigger" class="header-action" type="button" aria-label="Найти сообщение" :aria-expanded="searchOpen" @click="toggleSearch"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg></button><template #overflow><ConversationOverflowMenu show-files @search="openSearch" @files="filesOpen = true" /></template></WorkspaceHeaderActions>
    </header>
    <div v-if="searchMounted" v-show="searchOpen && !contextOpen()" class="conversation-tools"><KeepAlive><DirectMessageSearch v-if="searchOpen" :key="props.directMessageId" :direct-message-id="props.directMessageId" @open="searchTarget.open({ kind: 'DIRECT_MESSAGE', conversationId: props.directMessageId, messageId: $event })" @close="closeSearch" /></KeepAlive></div>
    <p v-if="store.loadingHistory" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" id="direct-conversation-error" class="state state-error" role="alert">{{ store.error }} <span v-if="store.historyLoaded">Показанная история может быть устаревшей.</span> <button v-if="store.retryableError" type="button" @click="store.refreshHistory()">Повторить загрузку</button></p>
    <div v-if="!filesOpen && unreadBoundary && !readUnlocked" class="unread-boundary-actions" role="status">
      <span>Есть непрочитанные сообщения.</span>
      <button type="button" @click="showUnread">К первому непрочитанному</button>
      <button type="button" @click="continueAtLatest">Остаться у последних</button>
    </div>
    <ConversationFilesPanel v-if="filesOpen" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :deleted-message-ids="store.deletedMessageIds" @open-message="filesOpen = false; searchTarget.open({ kind: 'DIRECT_MESSAGE', conversationId: props.directMessageId, messageId: $event })" @close="filesOpen = false; void nextTick(() => searchTrigger?.focus())" />
    <SearchMessageContext v-else-if="contextTarget" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="contextTarget.messageId" @close="searchTarget.clear()" />
    <SearchMessageContext v-else-if="replyContextTarget" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="replyContextTarget" heading="Контекст ответа" @close="replyContextTarget = null" />
    <SearchMessageContext v-else-if="unreadContextOpen" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="unreadBoundary" heading="Первое непрочитанное сообщение" unread :active="props.active" @read="store.refreshNavigation()" @viewport-change="savePosition" @close="continueAtLatest" />
    <SearchMessageContext v-else-if="restored" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="restored.id" :offset="restored.offset" heading="Сохранённая позиция" @viewport-change="savePosition" @close="restored = null" />
    <DirectMessageHistoryList v-show="!contextOpen()" :direct-message-id="props.directMessageId" :session="session" :other-participant-id="props.otherParticipantId" :other-participant-display-name="props.otherParticipantDisplayName" @reply="replyTarget = $event" @reply-context="replyContextTarget = $event" @retry="retry" @viewport-change="onViewportChange" />
    <div class="composer-wrap">
      <MentionAutocomplete v-model="draft" v-model:mention-user-ids="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" :only-participant="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }" />
      <form class="message-composer composer" @submit.prevent="send" @dragover="onDragOver" @drop="onDrop">
        <p v-if="replyTarget" class="reply-target">Ответ для {{ authors.displayName(replyTarget.authorId) }} <button type="button" @click="replyTarget = null">Отмена</button></p>
        <DirectMessageAttachmentPicker ref="attachmentPicker" :direct-message-id="props.directMessageId" :initial-attachments="attachments" :disabled="store.sending" :clear-token="attachmentClearToken" @change="attachments = $event" @pending="attachmentPending = $event" @mention="insertMobileMention" @emoji="emojiPicker?.show()" />
        <MentionPicker v-model="mentionUserIds" :self-id="session?.accountId ?? ''" :disabled="store.sending || !session" :only-participant="{ id: props.otherParticipantId, displayName: props.otherParticipantDisplayName }" quick @activate="insertMobileMention" />
        <label class="gc-sr-only" for="direct-message-body">Сообщение</label>
        <textarea id="direct-message-body" ref="composerTextarea" v-model="draft" rows="1" :disabled="store.sending" :aria-describedby="store.error ? 'direct-conversation-error direct-composer-help' : 'direct-composer-help'" placeholder="Написать сообщение…" @keydown="submitOnComposerEnter($event, send)" @paste="onComposerPaste" />
        <EmojiPicker ref="emojiPicker" :disabled="store.sending" @select="addEmoji" />
        <button v-action-hint class="composer-send" type="submit" :aria-label="store.sending ? 'Отправляем сообщение' : 'Отправить сообщение'" :disabled="store.sending || attachmentPending || (!draft && attachments.length === 0)"><span v-if="store.sending">…</span><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m22 2-7 20-4-9-9-4 20-7ZM22 2 11 13"/></svg></button>
      </form>
      <div class="composer-helper"><p id="direct-composer-help" class="composer-shortcut-help">Enter — отправить · Shift + Enter — новая строка</p><p class="composer-helper__limit">Файлы до 25 МБ</p></div>
    </div>
  </section>
</template>
