<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { formatFileSize, loadConversationFilePage, mapConversationFiles, type ConversationFileItem, type ConversationFileMessage } from './files_panel'

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
  } catch {
    if (current === generation) error.value = 'Не удалось загрузить файлы беседы.'
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
    <header><h3 id="conversation-files-title" ref="title" tabindex="-1">Файлы беседы</h3><button type="button" @click="emit('close')">Закрыть</button></header>
    <p v-if="pending && !loaded" role="status">Загружаем файлы…</p>
    <p v-if="error" role="alert">{{ error }} <button type="button" :disabled="pending" @click="loadPage">Повторить</button></p>
    <p v-if="loaded && !files.length && !cursor" role="status">В этой беседе пока нет файлов.</p>
    <table v-if="files.length">
      <thead><tr><th scope="col">Тип</th><th scope="col">Имя</th><th scope="col">Размер</th><th scope="col">Дата</th><th scope="col">Сообщение</th></tr></thead>
      <tbody><tr v-for="file in files" :key="file.id">
        <td>{{ file.typeLabel }}</td><td class="conversation-files__name">{{ file.originalName }}</td><td>{{ formatFileSize(file.sizeBytes) }}</td>
        <td><time :datetime="file.createdAt">{{ new Date(file.createdAt).toLocaleDateString('ru-RU') }}</time></td>
        <td><button type="button" :aria-label="`Перейти к сообщению с файлом ${file.originalName}`" @click="emit('openMessage', file.messageId)">К сообщению</button></td>
      </tr></tbody>
    </table>
    <button v-if="cursor" type="button" :disabled="pending" @click="loadPage">{{ pending ? 'Загружаем…' : 'Показать более старые файлы' }}</button>
  </section>
</template>

<style scoped>
.conversation-files { display: flex; flex-direction: column; gap: var(--gc-space-3); padding: var(--gc-space-4); overflow: auto; background: var(--gc-content); color: var(--gc-text-primary); }
.conversation-files header { display: flex; align-items: center; gap: var(--gc-space-3); }
.conversation-files header h3 { flex: 1; }
.conversation-files table { width: 100%; border-collapse: collapse; }
.conversation-files th, .conversation-files td { border-bottom: 1px solid var(--gc-border-subtle); padding: var(--gc-space-2); text-align: start; }
.conversation-files th { overflow-wrap: anywhere; color: var(--gc-text-muted); font-weight: var(--gc-weight-medium); }
.conversation-files__name { overflow-wrap: anywhere; }
</style>
