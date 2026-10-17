<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { buildQuickJumpEntries, type QuickJumpChannel, type QuickJumpPerson, type QuickJumpTarget } from './quick_jump'

const props = defineProps<{ channels: QuickJumpChannel[]; people: QuickJumpPerson[]; status: string; peopleLoading?: boolean; peopleError?: string; hasMore?: boolean }>()
const emit = defineEmits<{ select: [entry: QuickJumpTarget]; next: []; retry: [] }>()
const query = ref('')
const input = ref<HTMLInputElement | null>(null)
const entries = computed(() => buildQuickJumpEntries(query.value, props.channels, props.people))
onMounted(() => input.value?.focus())
</script>

<template>
  <section class="search-panel quick-jump-panel" aria-labelledby="quick-jump-title" data-testid="quick-jump-panel">
    <header class="search-panel-heading"><h1 id="quick-jump-title">Каналы и люди</h1></header>
    <label class="search-query-label"><span class="visually-hidden">Найти канал или человека</span><input ref="input" class="gc-field" v-model="query" type="search" autocomplete="off" placeholder="Поиск"></label>
    <p v-if="status" class="search-status search-status--visible" role="status" aria-live="polite">{{ status }}</p>
    <ol v-if="entries.length" class="quick-jump-results result-list" aria-label="Каналы и участники гильдии">
      <li v-for="entry in entries" :key="`${entry.kind}:${entry.id}`" class="result-row">
        <button class="result-open" type="button" :data-kind="entry.kind" @click="emit('select', { kind: entry.kind, id: entry.id })">
          <span class="result-title" :title="entry.title">{{ entry.title }}</span><small class="result-meta">{{ entry.subtitle }}</small>
        </button>
      </li>
    </ol>
    <p v-else-if="!status && !peopleLoading" class="search-status search-status--visible" role="status">Совпадений нет.</p>
    <p v-if="peopleLoading" role="status">Загружаем участников…</p>
    <p v-if="peopleError" role="alert">{{ peopleError }} <button class="gc-button gc-button--secondary" type="button" :disabled="peopleLoading" @click="emit('retry')">Повторить</button></p>
    <button v-else-if="hasMore" class="gc-button gc-button--secondary" type="button" :disabled="peopleLoading" :aria-busy="peopleLoading" @click="emit('next')">Показать ещё участников</button>
  </section>
</template>
