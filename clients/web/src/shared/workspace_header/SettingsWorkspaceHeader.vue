<script setup lang="ts">
import WorkspaceHeaderActions from './WorkspaceHeaderActions.vue'
import { vActionHint } from '../action_hint/directive'

defineProps<{ panel: 'audio' | 'profile' | 'admin'; navExpanded: boolean }>()
const emit = defineEmits<{ toggleNavigation: []; close: [] }>()
const labels = {
  audio: { title: 'Настройки аудио', close: 'Закрыть настройки аудио' },
  profile: { title: 'Настройки', close: 'Закрыть настройки' },
  admin: { title: 'Администрирование', close: 'Закрыть администрирование' },
}
const compactTitles = { audio: 'Аудио', profile: 'Настройки', admin: 'Админ' }
</script>

<template>
  <header class="settings-workspace-header">
    <WorkspaceHeaderActions :members-expanded="false" :nav-expanded="navExpanded" :show-members="false" @toggle-navigation="emit('toggleNavigation')" />
    <span class="settings-workspace-icon-wrap" aria-hidden="true">
      <svg class="settings-workspace-icon" viewBox="0 0 24 24">
        <template v-if="panel === 'admin'"><path d="m12 2 9 4v6c0 5-6 9-9 10-3-1-9-5-9-10V6l9-4Z"/><path d="m8 12 3 3 5-6"/></template>
        <template v-else><path d="m9 3 1-1h4l1 3 3 1 3 1v4l-2 2 1 3-3 3-3-1-2 2H8l-1-3-3-1-2-2 1-4 3-1 1-3Z"/><circle cx="12" cy="11" r="3"/></template>
      </svg>
    </span>
    <strong>
      <span class="settings-workspace-title-full gc-sr-only">{{ labels[panel].title }}</span>
      <span class="settings-workspace-title-compact" aria-hidden="true">{{ compactTitles[panel] }}</span>
    </strong>
    <button v-action-hint class="settings-workspace-close" type="button" :aria-label="labels[panel].close" @click="emit('close')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>
    </button>
  </header>
</template>
