<script setup lang="ts">
import type { SoundSettings } from './state'

defineProps<{ settings: SoundSettings; ready: boolean; unsynchronised: boolean }>()
const emit = defineEmits<{ change: [Partial<SoundSettings>]; preview: ['joined' | 'left' | 'started' | 'stopped'] }>()
const events = [
  { key: 'joined', label: 'Кто-то вошёл' },
  { key: 'left', label: 'Кто-то вышел' },
  { key: 'started', label: 'Трансляция началась' },
  { key: 'stopped', label: 'Трансляция закончилась' },
] as const
function checked(key: keyof SoundSettings, event: Event) { emit('change', { [key]: (event.target as HTMLInputElement).checked }) }
function volume(event: Event) { emit('change', { volume: Number((event.target as HTMLInputElement).value) }) }
</script>

<template>
  <section class="voice-sounds" aria-label="Звуки голосового канала">
    <h3>Звуки голосового канала</h3>
    <label><input type="checkbox" :checked="settings.enabled" :disabled="!ready" @change="checked('enabled', $event)"> Включить звуковые уведомления</label>
    <div v-for="item in events" :key="item.key" class="event">
      <label><input type="checkbox" :checked="settings[item.key]" :disabled="!ready" @change="checked(item.key, $event)"> {{ item.label }}</label>
      <button type="button" :disabled="!ready || !settings.enabled || !settings[item.key]" :aria-label="`Прослушать: ${item.label}`" @click="emit('preview', item.key)">Прослушать</button>
    </div>
    <label><input type="checkbox" :checked="settings.allow_custom" :disabled="!ready" @change="checked('allow_custom', $event)"> Мелодии входа других участников</label>
    <label>Громкость уведомлений: {{ settings.volume }}% <input type="range" min="0" max="100" :value="settings.volume" :disabled="!ready" @input="volume"></label>
    <p v-if="unsynchronised" role="status">Не синхронизировано. Проверьте соединение и повторите сохранение.</p>
  </section>
</template>

<style scoped>
.voice-sounds { display: grid; gap: 10px }
.voice-sounds label { display: flex; align-items: center; gap: 8px }
.event { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px }
</style>
