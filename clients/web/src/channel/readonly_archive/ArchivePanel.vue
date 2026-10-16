<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import ArchiveReader from './ArchiveReader.vue'
import ArchiveManagement from './ArchiveManagement.vue'
import { loadArchives, ArchiveRequestError, type ArchivedChannel } from './client'
defineProps<{ embedded?: boolean }>()
const channels = ref<ArchivedChannel[]>([]), selected = ref(''), cursor = ref(''), error = ref(''), loading = ref(false), canManage = ref(false), revision = ref(1), generation = ref(0)
let sequence = 0
async function load(more = false): Promise<void> {
  const ticket = ++sequence; loading.value = true; error.value = ''
  if (!more) { selected.value = ''; channels.value = []; cursor.value = ''; generation.value++ }
  try { const page = await loadArchives(more ? cursor.value : undefined); if (ticket !== sequence) return; channels.value = more ? [...channels.value, ...page.channels] : page.channels; cursor.value = page.next_cursor ?? ''; revision.value = page.revision; canManage.value = page.can_manage }
  catch (reason) { if (ticket === sequence) { if (reason instanceof ArchiveRequestError && [401, 403, 404].includes(reason.status)) { channels.value = []; selected.value = ''; cursor.value = ''; canManage.value = false; generation.value++ }; error.value = reason instanceof Error ? reason.message : 'Не удалось загрузить архив.' } }
  finally { if (ticket === sequence) loading.value = false }
}
onMounted(() => { void load() }); onBeforeUnmount(() => { sequence++ })
</script>
<template>
  <section class="archive-panel" aria-label="Архив текстовых каналов"><h2 v-if="!embedded">Архив TEXT-каналов</h2><div class="result-toolbar"><span class="result-meta">{{ channels.length || '' }}</span><button class="gc-button gc-button--secondary" type="button" :disabled="loading" @click="load()">Обновить</button></div><p v-if="loading" role="status">Загрузка…</p><p v-if="error" role="alert">{{ error }}</p><p v-else-if="!loading && !channels.length">Архивных каналов нет.</p><label v-if="channels.length">Канал <select class="gc-field" v-model="selected" aria-label="Канал"><option value="">Выберите архив</option><option v-for="channel in channels" :key="channel.id" :value="channel.id">{{ channel.category_name }} / {{ channel.name }}</option></select></label><button v-if="cursor" class="gc-button gc-button--secondary" type="button" :disabled="loading" @click="load(true)">Ещё каналы</button><ArchiveReader v-if="selected" :channel-id="selected" /><ArchiveManagement v-if="canManage" :key="generation" :revision="revision" :selected-archive="selected" @changed="load()" /></section>
</template>
<style scoped>.archive-panel { padding: 8px 16px; display: grid; gap: 12px; } .archive-panel > label { display: grid; min-width: 0; gap: var(--gc-space-2); }</style>
