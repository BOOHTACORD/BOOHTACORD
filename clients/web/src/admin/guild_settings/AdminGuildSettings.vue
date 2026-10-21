<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount } from 'vue'
import type { TopologyCategory } from '../../channel/topology_client'
import { createGuildSettingsState } from './state'
import AdminTelemetrySettings from '../telemetry/AdminTelemetrySettings.vue'
const props = defineProps<{ categories: TopologyCategory[] }>()
const state = createGuildSettingsState()
const { name, welcome, revision, busy, error, saved, dirty } = state
const channels = computed(() => props.categories.flatMap(category => category.channels).filter(channel => channel.kind === 'TEXT' && !channel.admissionClosed))
onMounted(() => { void state.load() }); onBeforeUnmount(state.dispose)
</script>
<template>
  <div>
  <form class="guild-settings" aria-label="Настройки гильдии" :aria-busy="busy" @submit.prevent="state.save(channels.map(channel => channel.id))">
    <h2>Гильдия</h2>
    <label for="guild-name">Название гильдии</label><input id="guild-name" class="gc-field" v-model="name" :disabled="busy || !revision" autocomplete="off" aria-describedby="guild-name-help">
    <small id="guild-name-help">От 1 до 80 символов, без переводов строк.</small>
    <label for="guild-welcome">Приветствия новых участников</label>
    <select id="guild-welcome" class="gc-field" v-model="welcome" :disabled="busy || !revision">
      <option :value="null">Не отправлять</option>
      <option v-if="welcome && !channels.some(channel => channel.id === welcome)" :value="welcome" disabled>Выбранный канал недоступен</option>
      <option v-for="channel in channels" :key="channel.id" :value="channel.id"># {{ channel.name }}</option>
    </select>
    <small v-if="!channels.length">Нет доступных текстовых каналов. Приветствия можно оставить выключенными.</small>
    <p v-if="error" role="alert">{{ error }}</p>
    <div class="settings-actions"><span role="status" aria-live="polite">{{ busy ? revision ? 'Сохраняем…' : 'Загружаем…' : dirty ? 'Есть несохранённые изменения' : saved ? 'Настройки сохранены.' : 'Изменения не внесены' }}</span>
    <button class="gc-button gc-button--secondary" type="button" :disabled="busy || !dirty" @click="state.cancel">Отменить</button>
    <button class="gc-button" type="submit" :aria-busy="busy" :disabled="busy || !revision || !dirty">{{ busy ? 'Сохраняем…' : 'Сохранить' }}</button></div>
    <button v-if="!revision && !busy" class="gc-button gc-button--secondary" type="button" @click="state.load">Загрузить настройки</button>
    <details class="copy-help"><summary>О названии гильдии</summary><p>Название отображается участникам и на экране входа.</p></details>
  </form>
  <AdminTelemetrySettings />
  </div>
</template>
<style scoped>
.guild-settings { display: grid; gap: 12px; max-width: 580px; padding: 24px; }
.guild-settings .gc-button { justify-self: start; }
</style>
