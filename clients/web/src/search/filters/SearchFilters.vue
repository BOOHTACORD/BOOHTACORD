<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useMemberDirectory } from '../../identity/member_directory'
import type { AttachmentFilter } from './state'

const props = defineProps<{
  authorId: string
  attachment: AttachmentFilter
  dateFrom: string
  dateTo: string
  disabled?: boolean
}>()
const emit = defineEmits<{
  'update:authorId': [value: string]
  'update:attachment': [value: AttachmentFilter]
  'update:dateFrom': [value: string]
  'update:dateTo': [value: string]
}>()
const members = useMemberDirectory()
const authorOptions = computed(() =>
  [...members.members].sort((left, right) =>
    left.display_name.localeCompare(right.display_name, 'ru'),
  ),
)
type Filter = 'author' | 'attachment' | 'from' | 'to'
const active = computed<{ key: Filter; label: string }[]>(() => [
  ...(props.authorId ? [{ key: 'author' as const, label: `Автор: ${authorOptions.value.find(member => member.user_id === props.authorId)?.display_name ?? 'Выбранный автор'}` }] : []),
  ...(props.attachment !== 'any' ? [{ key: 'attachment' as const, label: props.attachment === 'with' ? 'С вложениями' : 'Без вложений' }] : []),
  ...(props.dateFrom ? [{ key: 'from' as const, label: `С ${props.dateFrom}` }] : []),
  ...(props.dateTo ? [{ key: 'to' as const, label: `По ${props.dateTo}` }] : []),
])
function clear(key: Filter): void {
  if (key === 'author') emit('update:authorId', '')
  else if (key === 'attachment') emit('update:attachment', 'any')
  else if (key === 'from') emit('update:dateFrom', '')
  else emit('update:dateTo', '')
}
function clearAll(): void { for (const filter of active.value) clear(filter.key) }

onMounted(() => {
  if (!members.members.length && !members.loading) void members.refresh()
})
</script>

<template>
  <div class="search-filter-controls">
  <details class="search-filter-disclosure">
    <summary>Фильтры<span v-if="active.length"> ({{ active.length }})</span></summary>
    <fieldset class="search-filters" :disabled="disabled">
    <legend class="gc-sr-only">Фильтры поиска</legend>
    <label>
      <span>Автор</span>
      <select aria-label="Автор" :value="authorId" @change="emit('update:authorId', ($event.target as HTMLSelectElement).value)">
        <option value="">Любой автор</option>
        <option v-for="member in authorOptions" :key="member.user_id" :value="member.user_id">
          {{ member.display_name }} ({{ member.login }})
        </option>
      </select>
    </label>
    <p v-if="members.error" class="search-filter-error" role="alert">
      Не удалось загрузить список авторов.
    </p>
    <button v-if="members.cursor" type="button" :disabled="members.loading" @click="members.loadNext()">
      {{ members.loading ? 'Загружаем…' : 'Загрузить ещё участников' }}
    </button>
    <label>
      <span>Вложения</span>
      <select aria-label="Вложения" :value="attachment" @change="emit('update:attachment', ($event.target as HTMLSelectElement).value as AttachmentFilter)">
        <option value="any">Любые</option>
        <option value="with">С вложениями</option>
        <option value="without">Без вложений</option>
      </select>
    </label>
    <label><span>С даты</span><input type="date" :value="dateFrom" :max="dateTo || undefined" @input="emit('update:dateFrom', ($event.target as HTMLInputElement).value)"></label>
    <label><span>По дату</span><input aria-label="По дату включительно" type="date" :value="dateTo" :min="dateFrom || undefined" @input="emit('update:dateTo', ($event.target as HTMLInputElement).value)"></label>
    <small>Даты в вашем часовом поясе.</small>
  </fieldset>
  </details>
  <div v-if="active.length" class="search-active-filters" role="group" aria-label="Активные фильтры" data-testid="active-search-filters">
    <button v-for="filter in active" :key="filter.key" type="button" :disabled="disabled" :aria-label="`Сбросить фильтр: ${filter.label}`" :title="filter.label" @click="clear(filter.key)"><span>{{ filter.label }}</span><span aria-hidden="true">×</span></button>
    <button class="search-clear-filters" type="button" :disabled="disabled" @click="clearAll">Сбросить фильтры</button>
  </div>
  </div>
</template>

<style scoped>
.search-filters { display: flex; flex-wrap: wrap; min-width: 0; align-items: end; gap: 8px 12px; border: 0; margin: 0; padding: 0; }
.search-filters legend { font-size: 0.85rem; font-weight: 600; margin-bottom: 6px; }
.search-filters label { display: grid; gap: 4px; }
.search-filters input, .search-filters select, .search-filters button { min-height: 44px; }
.search-filter-error { margin: 0; }
.search-filters small { flex-basis: 100%; }
</style>
