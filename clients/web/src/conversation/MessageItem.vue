<script setup lang="ts">
import { computed,nextTick,onMounted,onUpdated,ref,watch } from 'vue'
import { markRendered } from '../telemetry/journey_intervals/runtime'

import type { TextMessage, TextMessageAttachment } from './message_client'
import { avatarFallbackStyle } from './avatar_fallback'
import { avatarInitials } from '../design/avatar_initials'
import { useAuthorDirectory } from '../identity/author_directory'
import MessageTimestamp from './MessageTimestamp.vue'
import MessageBody from './message_body/MessageBody.vue'
import { decorateMessageMentions } from './message_body/inline_mentions'
import MentionPicker from './MentionPicker.vue'
import TextMessageAttachments from './TextMessageAttachments.vue'
import DirectMessageAttachments from '../direct_message/DirectMessageAttachments.vue'
import { useMessageEditController, type EditResult } from './message_edit_controller'
import { handleMessageEditKeydown } from './message_edit_shortcuts'
import { useMessageActionDisclosure } from './message_actions/disclosure'
import SystemWelcomeMessage from './system_welcome/SystemWelcomeMessage.vue'
import ReactionBar from './reactions/ReactionBar.vue'
import PinMessageButton from './pins/PinMessageButton.vue'

type RenderedMessage = Omit<TextMessage, 'channelId' | 'attachments' | 'mentionUserIds'> & { channelId?: string; directMessageId?: string; attachments?: TextMessageAttachment[]; mentionUserIds?: string[] }

const props = defineProps<{ message: RenderedMessage; grouped?: boolean; replyPreview?: string; canEdit: boolean; canDelete: boolean; retryDisabled?: boolean; mentionRecipient?: { id: string; displayName: string }; editMessage?: (body: string, mentionIds: string[], revision: number) => Promise<EditResult>; refreshMessage?: () => Promise<{ revision: number; deleted: boolean } | null> }>()
const emit = defineEmits<{ remove: []; reply: []; retry: []; replyContext: [messageId: string]; editState: [editing: boolean] }>()
onMounted(()=>markRendered(props.message));onUpdated(()=>markRendered(props.message))
const editor = useMessageEditController({
  save: (body, ids, revision) => props.editMessage?.(body, ids, revision) ?? Promise.resolve({ kind: 'stale', message: 'Сообщение недоступно.' }),
  refresh: () => props.refreshMessage?.() ?? Promise.resolve(null),
})
const { editing, body, mentionUserIds: editingMentionIds, pending, needsRefresh, error: editError, notice: editNotice } = editor
watch(editing, (value) => emit('editState', value), { flush: 'sync' })
const textChannelId = computed(() => props.message.channelId ?? '')
const textAttachments = computed(() => props.message.attachments ?? [])
const authors = useAuthorDirectory()
const authorName = computed(() => authors.displayName(props.message.authorId))
const authorAvatar = computed(() => authors.avatarUrl(props.message.authorId))
const mentionRecipients = computed(() => (props.message.mentionUserIds ?? []).map((id) => ({ id, name: authors.displayName(id) })))
const unmatchedMentionIds = computed(() => decorateMessageMentions(props.message.body, mentionRecipients.value).unmatchedIds)
const compact = computed(() => Boolean(props.grouped && !editing.value))
const avatarFailed = ref(false)
const editInput = ref<HTMLTextAreaElement | null>(null)
const { actionsOpen, actionsToggle, row, closeActions, onRowPointerDown, onRowPointerMove, onRowPointerEnd, onRowFocusOut } = useMessageActionDisclosure()
watch(() => props.message.authorId, (id) => { void authors.ensure(id) }, { immediate: true })
watch(() => props.message.mentionUserIds, (ids) => { for (const id of ids ?? []) void authors.ensure(id) }, { immediate: true })
watch(authorAvatar, () => { avatarFailed.value = false })

function beginEdit(): void {
  actionsOpen.value = false
  editor.begin(props.message)
  void nextTick(() => editInput.value?.focus())
}
function onEditKeydown(event: KeyboardEvent): void {
  handleMessageEditKeydown(event, () => {
    editor.cancel()
    void nextTick(() => row.value?.focus())
  }, () => { void editor.submit() })
}

function closeActionsAndRestoreFocus(): void {
  actionsOpen.value = false
  void nextTick(() => {
    if (actionsToggle.value?.isConnected && actionsToggle.value.getClientRects().length > 0) actionsToggle.value.focus()
    else row.value?.focus()
  })
}
function reply(): void { closeActionsAndRestoreFocus(); emit('reply') }
function remove(): void {
  if (window.confirm('Удалить это сообщение?')) { closeActionsAndRestoreFocus(); emit('remove') }
}

</script>

<template>
  <SystemWelcomeMessage v-if="message.kind === 'SYSTEM_WELCOME'" :body="message.body" :author-id="message.authorId" :created-at="message.createdAt" :deleted="message.deleted" :can-delete="canDelete" @remove="emit('remove')" />
  <article v-else ref="row" class="message-item message-row" :class="{ deleted: message.deleted, grouped: compact }" tabindex="-1" @pointerdown="onRowPointerDown" @pointermove="onRowPointerMove" @pointerup="onRowPointerEnd" @pointercancel="onRowPointerEnd" @focusout="onRowFocusOut">
    <span v-if="compact" class="message-avatar-spacer"><MessageTimestamp :created-at="message.createdAt" /></span>
    <img v-else-if="authorAvatar && !avatarFailed" class="message-avatar" :src="authorAvatar" alt="" @error="avatarFailed = true">
    <span v-else class="message-avatar" :style="avatarFallbackStyle(message.authorId)" aria-hidden="true">{{ avatarInitials(authorName) }}</span>
    <div class="message-content">
      <div v-if="!compact" class="message-meta">
        <span class="message-author">{{ authorName }}</span>
        <MessageTimestamp :created-at="message.createdAt" />
        <span v-if="message.editedAt" class="message-time">изменено</span>
      </div>
      <span v-else class="gc-sr-only">{{ authorName }}<span v-if="message.editedAt">, изменено</span></span>
      <template v-if="editing">
        <textarea ref="editInput" v-model="body" :disabled="pending" aria-label="Изменённый текст сообщения" :aria-describedby="editError ? `message-edit-error-${message.id}` : undefined" @keydown="onEditKeydown" />
        <MentionPicker v-model="editingMentionIds" :self-id="message.authorId" :disabled="pending" :only-participant="mentionRecipient" />
        <p v-if="editError" :id="`message-edit-error-${message.id}`" class="message-send-status" role="alert">{{ editError }}</p>
        <p v-if="editNotice" class="message-send-status" role="status">{{ editNotice }}</p>
        <button type="button" :disabled="pending || needsRefresh || !body" @click="editor.submit()">{{ pending ? 'Обрабатываем…' : 'Сохранить' }}</button>
        <button v-if="needsRefresh" type="button" :disabled="pending" @click="editor.refreshVersion()">Обновить версию</button>
        <button type="button" :disabled="pending" @click="editor.cancel()">Отмена</button>
      </template>
      <p v-else-if="message.deleted">Сообщение удалено</p>
      <template v-else>
        <button v-if="replyPreview && message.replyToId" class="reply-preview" type="button" aria-label="Открыть контекст ответа" @click="emit('replyContext', message.replyToId)">↪ {{ replyPreview }}</button>
        <MessageBody :body="message.body" :mentions="mentionRecipients" />
        <p v-if="unmatchedMentionIds.length" class="message-mentions">Упомянуты: <span v-for="id in unmatchedMentionIds" :key="id">@{{ authors.displayName(id) }} </span></p>
        <TextMessageAttachments v-if="textChannelId && textAttachments.length" :channel-id="textChannelId" :attachments="textAttachments" />
        <DirectMessageAttachments v-if="message.directMessageId && textAttachments.length" :direct-message-id="message.directMessageId" :attachments="textAttachments" />
        <ReactionBar v-if="!message.sendStatus&&(message.channelId||message.directMessageId)" v-slot="{canPin}" :kind="message.directMessageId?'DIRECT_MESSAGE':'CHANNEL'" :conversation-id="message.directMessageId??message.channelId??''" :message-id="message.id"><PinMessageButton v-if="canPin&&message.channelId" :channel-id="message.channelId" :message-id="message.id" /></ReactionBar>
        <p v-if="message.sendStatus === 'sending'" class="message-send-status" role="status">Отправляется…</p>
        <p v-if="message.sendStatus === 'checking'" class="message-send-status" role="status">Проверяем доставку…</p>
        <div v-if="message.sendStatus === 'failed'" class="message-send-status" role="alert"><span>Не отправлено</span><button type="button" :disabled="retryDisabled || message.retryBlocked" @click="emit('retry')">Повторить отправку</button><button type="button" :disabled="retryDisabled" @click="emit('remove')">Убрать из очереди</button><small v-if="message.retryBlocked">Исправьте сообщение или доступ перед новой отправкой.</small></div>
      </template>
      <div v-if="!editing && !message.deleted && !message.sendStatus" class="message-actions" :class="{ 'is-open': actionsOpen }" @keydown.esc="closeActions">
        <button ref="actionsToggle" class="message-actions-toggle" type="button" aria-label="Действия с сообщением" :aria-expanded="actionsOpen" :aria-controls="`message-actions-${message.id}`" @click="actionsOpen = !actionsOpen">⋯</button>
        <div :id="`message-actions-${message.id}`" class="message-action-buttons">
          <button type="button" @click="reply">Ответить</button>
          <button v-if="canEdit" type="button" @click="beginEdit">Изменить</button>
          <button v-if="canDelete" type="button" @click="remove">Удалить</button>
        </div>
      </div>
    </div>
  </article>
</template>
