<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { onBeforeUnmount, ref, watch } from 'vue'

import type { TextAttachmentUpload } from './text_attachment_upload_client'
import { useTextAttachmentQueue } from './text_attachment_queue'
import { useCompactComposerActions } from './use_compact_composer_actions'

import QueueList from './upload_queue/QueueList.vue'
const props = defineProps<{ channelId: string; disabled: boolean; clearToken: number; initialAttachments?: TextAttachmentUpload[] }>()
const emit = defineEmits<{ change: [attachments: TextAttachmentUpload[]]; pending: [value: boolean]; mention: []; emoji: [] }>()
const fileInput = ref<HTMLInputElement | null>(null)
const { compact, menuOpen, trigger, firstAction, toggle, close, onFocusOut } = useCompactComposerActions()
function openActions(): void { if (compact.value) toggle(); else fileInput.value?.click() }
function chooseFile(): void { close(); fileInput.value?.click() }
function chooseMention(): void { close(); emit('mention') }
function chooseEmoji(): void { close(); emit('emoji') }
const { items, pending, error, clear, restore, upload, addFiles, retry, cancel, dispose } = useTextAttachmentQueue(
  () => props.channelId, () => props.disabled, emit, undefined, props.initialAttachments,
)
onBeforeUnmount(dispose)
watch(() => props.clearToken, clear)
watch(() => props.channelId, () => restore(props.initialAttachments ?? []))

function addPastedFiles(files: File[]): void { void upload(files) }
defineExpose({ addPastedFiles })
</script>

<template>
  <section class="attachment-picker" aria-labelledby="message-attachments-label">
    <input ref="fileInput" id="message-attachments" class="attachment-input" type="file" multiple tabindex="-1" aria-hidden="true" :disabled="props.disabled" @change="addFiles">
    <button v-action-hint id="message-attachments-label" ref="trigger" class="attachment-trigger" type="button" :aria-label="compact ? 'Действия редактора' : 'Прикрепить файлы'" :aria-expanded="compact ? menuOpen : undefined" :disabled="props.disabled" @click="openActions"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg></button>
    <div v-if="menuOpen" class="composer-mobile-actions" role="group" aria-label="Действия редактора" @keydown.esc.stop.prevent="close(true)" @focusout="onFocusOut">
      <button ref="firstAction" type="button" @click="chooseFile">Прикрепить файл</button>
      <button type="button" @click="chooseMention">Упомянуть</button>
      <button type="button" @click="chooseEmoji">Emoji</button>
    </div>
    <p class="attachment-hint">До 10 файлов по 25 МБ. Файлы будут прикреплены после отправки сообщения.</p>
    <p v-if="pending" class="attachment-state" aria-live="polite">Загружаем вложение…</p>
    <p v-if="error" class="attachment-state attachment-error" role="alert">{{ error }}</p>
    <QueueList :items="items" :disabled="props.disabled" @retry="retry" @cancel="cancel" />
  </section>
</template>
