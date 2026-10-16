<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { formatFileSize, loadConversationFilePage, mapConversationFiles, type ConversationFileItem, type ConversationFileMessage } from './files_panel'
import { MessageRequestError } from '../message_client'
import { DirectMessageRequestError } from '../../direct_message/direct_message_client'

const props = defineProps<{ kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; deletedMessageIds?: readonly string[] }>()
const emit = defineEmits<{ close: []; openMessage: [messageId: string] }>()
type Page = { messages: ConversationFileMessage[]; nextCursor?: string }
const files = ref<ConversationFileItem[]>([])
const cursor = ref<string>()
const pending = ref(false)
const loaded = ref(false)
const error = ref('')
const title = ref<HTMLHeadingElement | null>(null)
let generation = 0

async function loadPage(): Promise<void> {
  if (pending.value) return
  const current = generation
  pending.value = true
  error.value = ''
  try {
    const page: Page = await loadConversationFilePage(props.kind, props.conversationId, cursor.value)
    if (current !== generation) return
    const existing = new Map(files.value.map((file) => [file.id, file]))
    for (const file of mapConversationFiles(page.messages)) if (!existing.has(file.id)) existing.set(file.id, file)
    files.value = [...existing.values()].filter((file) => !props.deletedMessageIds?.includes(file.messageId))
    cursor.value = page.nextCursor
    loaded.value = true
  } catch (cause) {
    if (current === generation) {
      if ((cause instanceof MessageRequestError || cause instanceof DirectMessageRequestError) && [401, 403, 404].includes(cause.status)) { files.value = []; cursor.value = undefined; loaded.value = false }
      error.value = 'Не удалось загрузить файлы беседы.'
    }
  } finally {
    if (current === generation) pending.value = false
  }
}

watch(() => [props.kind, props.conversationId], () => {
  generation++
  files.value = []
  cursor.value = undefined
  pending.value = false
  loaded.value = false
  void loadPage()
}, { immediate: true })
watch(() => props.deletedMessageIds, (ids) => {
  const removed = new Set(ids ?? [])
  files.value = files.value.filter((file) => !removed.has(file.messageId))
}, { deep: true })
onBeforeUnmount(() => { generation++ })
onMounted(() => title.value?.focus())
</script>

<template>
  <section class="conversation-files" aria-labelledby="conversation-files-title">
    <header><h3 id="conversation-files-title" ref="title" tabindex="-1">Файлы беседы</h3><button class="gc-button gc-button--ghost" type="button" @click="emit('close')">Закрыть</button></header>
    <p v-if="pending && !loaded" role="status">Загружаем файлы…</p>
    <p v-if="error" role="alert">{{ error }} <button class="gc-button gc-button--secondary" type="button" :disabled="pending" @click="loadPage">Повторить</button></p>
    <p v-if="loaded && !files.length && !cursor" role="status">В этой беседе пока нет файлов.</p>
    <ol v-if="files.length" class="result-list" aria-label="Файлы беседы" :aria-busy="pending">
      <li v-for="file in files" :key="file.id" class="result-row">
        <details class="file-name-detail"><summary class="result-title" :title="file.originalName">{{ file.originalName }}</summary><p>{{ file.originalName }}</p></details>
        <div class="result-meta"><span>{{ file.typeLabel }}</span><span>{{ formatFileSize(file.sizeBytes) }}</span><time :datetime="file.createdAt">{{ new Date(file.createdAt).toLocaleDateString('ru-RU') }}</time></div>
        <button class="gc-button gc-button--secondary" type="button" :aria-label="`Перейти к сообщению с файлом ${file.originalName}`" @click="emit('openMessage', file.messageId)">К сообщению</button>
      </li>
    </ol>
    <button v-if="cursor" class="gc-button gc-button--secondary" type="button" :aria-busy="pending" :disabled="pending" @click="loadPage">{{ pending ? 'Загружаем…' : 'Показать более старые файлы' }}</button>
  </section>
</template>

<style scoped>
.conversation-files { display: flex; flex-direction: column; gap: var(--gc-space-3); padding: var(--gc-space-4); overflow: auto; background: var(--gc-content); color: var(--gc-text-primary); }
.conversation-files header { display: flex; flex-wrap: wrap; align-items: center; gap: var(--gc-space-3); }
.conversation-files header h3 { flex: 1; min-width: 0; margin: 0; font-size: 1rem; }
.file-name-detail { min-width: 0; }
.file-name-detail summary { cursor: pointer; min-height: 44px; align-content: center; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
.file-name-detail p { margin-block: 8px; overflow-wrap: anywhere; user-select: text; }
</style>
