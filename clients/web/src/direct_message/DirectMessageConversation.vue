<script setup lang="ts">
import { isSupportPeer,isProductSupportPeer, supportPrivacyNotice, supportPrompt } from '../support/contact'
import SupportPublicationConsent from '../support/SupportPublicationConsent.vue'
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
import type { DirectMessageHistoryItem } from './direct_message_client'
import { advanceReadIfVisible } from './direct_message_read_gate'
import { useDirectMessageStore } from './direct_message_store'
import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import { useSavedComposer } from '../conversation/use_saved_composer'
import { submitOnComposerEnter } from '../conversation/composer_enter'
import SearchMessageContext from '../search/SearchMessageContext.vue'
import { useSearchTargetStore } from '../search/search_target_store'
import { useScopedSend } from '../conversation/use_scoped_send'
import type { Position } from '../conversation/context_position/dom'
import { useContextPosition } from '../conversation/context_position/return'
import { useVisibleRead } from '../conversation/use_visible_read'
const props = defineProps<{ accountId: string; active: boolean; directMessageId: string; otherParticipantId: string; otherParticipantDisplayName: string; navOpen: boolean }>()
const emit = defineEmits<{ toggleNav: [] }>()
const store = useDirectMessageStore()
const support = computed(()=>isSupportPeer(props.otherParticipantId,store.supportContact))
const publicationBlocked=computed(()=>isProductSupportPeer(props.otherParticipantId,store.supportContact)&&(store.supportContact.mode!=='product'||store.supportContact.consentRequired||store.supportContact.state!=='available'))
const firstUnread = computed(() => store.directMessages.find(({ id }) => id === props.directMessageId)?.firstUnreadMessageId)
const searchTarget = useSearchTargetStore()
const filesOpen = ref(false)
const contextTarget = computed(() => searchTarget.target?.kind === 'DIRECT_MESSAGE' && searchTarget.target.conversationId === props.directMessageId ? searchTarget.target : null)
const historyList = ref<{ showMessage: (messageId: string) => Promise<boolean>; restoreMessagePosition: (position: Position) => Promise<boolean>; beginTargetNavigation: () => void; endTargetNavigation: () => void } | null>(null)
const searchNavigationError = ref('')
const replyContextTarget = ref<string | null>(null)
const authors = useAuthorDirectory()
const session = ref<CurrentSession | null>(null)
const composer = useSavedComposer<DirectMessageHistoryItem, TextMessageAttachment>(props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId)
const { draft, replyTarget, mentionUserIds, attachments, attachmentPending, attachmentClearToken } = composer
const overflow = ref<{ focus: () => void } | null>(null)
const composerTextarea = ref<HTMLTextAreaElement | null>(null)
const attachmentPicker = ref<{ addPastedFiles: (files: File[]) => void } | null>(null)
const emojiPicker = ref<{ show: () => Promise<void> } | null>(null)
const { readRoot, queueVisibleRead } = useVisibleRead({
  conversationId: () => props.directMessageId, loadedConversationId: () => store.directMessageId, messages: () => store.messages,
  firstUnreadMessageId: () => firstUnread.value,
  canRead: () => props.active && store.directMessages.some(({ id }) => id === props.directMessageId) && !filesOpen.value && !contextTarget.value && !replyContextTarget.value,
  advance: (id, messageId) => advanceReadIfVisible({ activeDirectMessageId: store.directMessageId,
    renderedDirectMessageId: id, newestDisplayedMessageId: messageId, visibilityState: document.visibilityState }),
  refreshCounters: () => { void store.refreshNavigation() },
})

const contextOpen = () => Boolean(filesOpen.value || replyContextTarget.value)
const { save: savePosition } = useContextPosition(props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId, readRoot, contextOpen, () => store.historyLoaded && store.directMessageId === props.directMessageId, restorePosition)
async function restorePosition(position: Position): Promise<void> {
  const directMessageId = props.directMessageId
  const list = historyList.value
  list?.beginTargetNavigation()
  try {
    const opened = await store.openAround(position.id)
    if (!opened || props.directMessageId !== directMessageId) return
    await store.loadNewer()
    await nextTick()
    if (props.directMessageId !== directMessageId) return
    await list?.restoreMessagePosition(position)
  } finally {
    await nextTick()
    list?.endTargetNavigation()
  }
}
function onViewportChange(): void { savePosition(); queueVisibleRead() }
const { send, retry } = useScopedSend<DirectMessageHistoryItem, TextMessageAttachment, DirectMessageHistoryItem>(
  props.accountId, 'DIRECT_MESSAGE', () => props.directMessageId, composer,
  () => !publicationBlocked.value && !attachmentPending.value && store.directMessageId === props.directMessageId,
  () => store.send(draft.value, undefined, undefined, replyTarget.value?.id, session.value?.accountId, mentionUserIds.value, attachments.value),
  (id) => store.retry(id),
)

async function loadSession(): Promise<void> {
  try { session.value = await loadCurrentSession() } catch { session.value = null }
}

const { addEmoji, insertMobileMention, onComposerPaste, onDragOver, onDrop } = useComposerInput(draft, composerTextarea, attachmentPicker, () => props.active && !store.sending)
let handledTargetKey = ''
watch([contextTarget, () => store.directMessageId, () => store.historyLoaded], async ([target, loadedId, loaded]) => {
  if (!target || loadedId !== props.directMessageId || !loaded) return
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
    else { searchNavigationError.value = 'Не удалось найти сообщение в личной переписке.'; searchTarget.clear() }
  } finally {
    await nextTick(); await nextTick()
    historyList.value?.endTargetNavigation()
  }
}, { flush: 'post' })
watch(() => searchTarget.target, (target) => { if (!target) handledTargetKey = '' })


onMounted(() => {
  void loadSession()
})
watch(() => props.directMessageId, () => { replyContextTarget.value = null })
onBeforeUnmount(() => searchTarget.clearFor('DIRECT_MESSAGE', props.directMessageId))
</script>

<template>
  <section ref="readRoot" class="direct-message-conversation" aria-labelledby="direct-message-title">
    <header class="main-header conversation-header">
      <span class="conversation-symbol conversation-symbol--person" aria-hidden="true"><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="3"/><path d="M5 20v-2a5 5 0 0 1 5-5h4a5 5 0 0 1 5 5v2"/></svg></span>
      <div class="main-title">
        <h2 id="direct-message-title" :title="props.otherParticipantDisplayName">{{ props.otherParticipantDisplayName }}</h2>
        <small>Личный диалог</small>
      </div>
      <WorkspaceHeaderActions :members-expanded="false" :nav-expanded="props.navOpen" :show-members="false" @toggle-navigation="emit('toggleNav')"><template #overflow><ConversationOverflowMenu ref="overflow" show-files @files="filesOpen = true" /></template></WorkspaceHeaderActions>
    </header>
    <p v-if="support" class="support-privacy" tabindex="0" role="region" aria-label="Приватность поддержки"><span v-if="store.supportChanged">Оператор поддержки изменился. Старые диалоги сохраняют прежних участников и историю. </span>{{ supportPrivacyNotice(store.supportContact,props.otherParticipantId) }}</p>
    <SupportPublicationConsent v-if="publicationBlocked" />
    <p v-if="store.loadingHistory" class="state" aria-live="polite">Загружаем историю…</p>
    <p v-if="store.error" id="direct-conversation-error" class="state state-error" role="alert">{{ store.error }} <span v-if="store.historyLoaded">Показанная история может быть устаревшей.</span> <button v-if="store.retryableError" type="button" @click="store.refreshHistory()">Повторить загрузку</button></p>
    <p v-if="searchNavigationError" class="state state-error" role="alert">{{ searchNavigationError }}</p>
    <ConversationFilesPanel v-if="filesOpen" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :deleted-message-ids="store.deletedMessageIds" @open-message="filesOpen = false; searchTarget.open({ kind: 'DIRECT_MESSAGE', conversationId: props.directMessageId, messageId: $event })" @close="filesOpen = false; void nextTick(() => overflow?.focus())" />
    <SearchMessageContext v-else-if="replyContextTarget" kind="DIRECT_MESSAGE" :conversation-id="props.directMessageId" :message-id="replyContextTarget" heading="Контекст ответа" @close="replyContextTarget = null" />
    <DirectMessageHistoryList ref="historyList" :empty-text="support ? supportPrompt : undefined" v-show="!contextOpen()" :direct-message-id="props.directMessageId" :session="session" :other-participant-id="props.otherParticipantId" :other-participant-display-name="props.otherParticipantDisplayName" @reply="replyTarget = $event" @reply-context="replyContextTarget = $event" @retry="retry" @viewport-change="onViewportChange" />
    <div v-if="!publicationBlocked" class="composer-wrap">
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
