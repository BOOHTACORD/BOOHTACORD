<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { archiveHistory, archiveSearch, archiveDownloadUrl } from './client'
import type { TextMessage } from '../../conversation/message_client'
import type { SearchMessage } from '../../search/search_messages_client'
import { useAuthorDirectory } from '../../identity/author_directory'
import { MessageRequestError } from '../../conversation/message_client'
const props = defineProps<{ channelId: string }>()
const authors = useAuthorDirectory()
const messages = ref<(TextMessage | SearchMessage)[]>([])
const query = ref(''), activeQuery = ref(''), cursor = ref(''), error = ref(''), loading = ref(false)
let sequence = 0
async function load(more = false, search = false): Promise<void> {
  const ticket = ++sequence, id = props.channelId, text = more ? activeQuery.value : search ? query.value.trim() : ''
  error.value = ''; loading.value = true
  try {
    const page = text ? await archiveSearch(id, text, more ? cursor.value : undefined) : await archiveHistory(id, more ? cursor.value : undefined)
    if (ticket !== sequence) return
    messages.value = more ? [...messages.value, ...page.messages] : page.messages
    cursor.value = page.nextCursor ?? ''; activeQuery.value = text
    for (const message of page.messages) void authors.ensure(message.authorId)
  } catch (reason) { if (ticket === sequence) { if (reason instanceof MessageRequestError && [401, 403, 404].includes(reason.status)) { messages.value = []; cursor.value = '' }; error.value = reason instanceof Error ? reason.message : 'Не удалось прочитать архив.' } }
  finally { if (ticket === sequence) loading.value = false }
}
watch(() => props.channelId, () => { sequence++; messages.value = []; cursor.value = ''; query.value = ''; void load() }, { immediate: true })
onBeforeUnmount(() => { sequence++ })
</script>
<template>
  <section aria-label="История архивного канала">
    <p role="note">Архив доступен только для чтения. Отправка и изменение сообщений отключены.</p>
    <form role="search" @submit.prevent="load(false, true)"><label>Поиск в архиве <input class="gc-field" v-model="query" type="search" maxlength="256" :disabled="loading"></label><button class="gc-button" :aria-busy="loading" :disabled="loading || !query.trim()">Найти</button><button class="gc-button gc-button--secondary" type="button" :disabled="loading" @click="load()">Вся история</button></form>
    <p v-if="error" role="alert">{{ error }}</p><p v-if="loading" role="status">Загрузка…</p><p v-else-if="!messages.length && !error" role="status">Сообщений нет.</p>
    <ol class="archive-messages result-list"><li v-for="message in messages" :key="message.id" class="result-row"><article><header class="result-meta"><span :title="authors.displayName(message.authorId)">{{ authors.displayName(message.authorId) }}</span> · <time :datetime="message.createdAt">{{ new Date(message.createdAt).toLocaleString('ru-RU') }}</time></header><p>{{ 'deleted' in message && message.deleted ? 'Сообщение удалено' : message.body }}</p><ul v-if="'attachments' in message"><li v-for="file in message.attachments" :key="file.id"><a :href="archiveDownloadUrl(channelId, file.id)" download>{{ file.originalName }}</a></li></ul></article></li></ol>
    <button v-if="cursor" class="gc-button gc-button--secondary" type="button" :disabled="loading" @click="load(true)">Показать ещё</button>
  </section>
</template>
<style scoped>
.archive-messages { list-style: none; padding: 0; } article { border-bottom: 1px solid var(--gc-border); padding: 12px 0; } article p { white-space: pre-wrap; overflow-wrap: anywhere; } header { color: var(--gc-text-muted); } input { max-width: 100%; } form { display: flex; align-items: end; gap: var(--gc-space-2); flex-wrap: wrap; } form label { display: grid; flex: 1 1 100%; min-width: 0; gap: var(--gc-space-2); }
</style>
