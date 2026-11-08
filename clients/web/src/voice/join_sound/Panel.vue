<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { JoinSoundClient, type JoinSound } from './client'
import { loadJoinSound } from '../sound_playback/custom_loader'
import { BrowserSoundPlayer } from '../sound_playback/browser'
const props = defineProps<{ accountId: string; muted?: boolean; volume?: number; output?: string }>()
const sound = ref<JoinSound | null>(null), busy = ref(false), error = ref('')
let lifetime = new AbortController()
let preview: AbortController | null = null
const player = new BrowserSoundPlayer(() => props.volume ?? 50, () => props.output ?? 'default')
async function run(action: (client: JoinSoundClient, signal: AbortSignal) => Promise<JoinSound | null>) {
  const current = lifetime; busy.value = true; error.value = ''
  try { const result = await action(new JoinSoundClient(props.accountId), current.signal); if (!current.signal.aborted) sound.value = result }
  catch (cause) { if (!current.signal.aborted) error.value = cause instanceof Error ? cause.message : 'Мелодия недоступна.' }
  finally { if (!current.signal.aborted) busy.value = false }
}
watch(() => props.accountId, () => { lifetime.abort(); preview?.abort(); lifetime = new AbortController(); sound.value = null; void run((c, s) => c.current(s)) }, { immediate: true })
watch(() => props.muted, muted => { if (muted) preview?.abort() })
onBeforeUnmount(() => { lifetime.abort(); preview?.abort() })
async function upload(event: Event) {
  const input = event.target as HTMLInputElement, file = input.files?.[0]; input.value = ''
  if (file) await run((c, s) => c.upload(file, s))
}
async function listen() {
  if (!sound.value || props.muted) return
  preview?.abort(); const current = preview = new AbortController(); const own = lifetime
  error.value = ''; busy.value = true
  try { const bytes = await loadJoinSound(sound.value.id, current.signal); if (!own.signal.aborted) await player.play('joined', bytes, current.signal) }
  catch { if (!current.signal.aborted && !own.signal.aborted) error.value = 'Не удалось воспроизвести мелодию. Проверьте звук и повторите попытку.' }
  finally { if (!own.signal.aborted) busy.value = false }
}
</script>
<template>
  <section class="join-sound-panel" aria-label="Персональная мелодия входа">
    <h3>Персональная мелодия входа</h3>
    <p>MP3, WAV или OGG · 0,3–3 секунды · до 2 МиБ. После загрузки включите мелодию отдельно.</p>
    <label>Загрузить мелодию <input type="file" accept=".mp3,.wav,.ogg,audio/mpeg,audio/wav,audio/ogg" :disabled="busy" @change="upload"></label>
    <template v-if="sound">
      <label><input type="checkbox" :checked="sound.enabled" :disabled="busy" @change="run((c, s) => c.enable(($event.target as HTMLInputElement).checked, s))"> Использовать при входе в канал</label>
      <button type="button" :disabled="busy || muted" @click="listen">Прослушать мелодию</button>
      <button type="button" :disabled="busy" @click="run((c, s) => c.remove(s))">Удалить мелодию</button>
    </template>
    <p v-if="busy" role="status">Обрабатываем мелодию…</p><p v-if="error" role="alert">{{ error }}</p>
  </section>
</template>
<style scoped>
.join-sound-panel { display: grid; min-width: 0; gap: 12px; margin-top: 24px; padding-bottom: 8px; overflow-wrap: anywhere }
.join-sound-panel > * { min-width: 0; max-width: 100% }
.join-sound-panel p { margin: 0 }
.join-sound-panel label { display: flex; flex-wrap: wrap; align-items: center; gap: 8px }
.join-sound-panel button { justify-self: start; min-height: 44px; padding: 8px 16px; border: 1px solid #434957; border-radius: 8px; background: #23262f; color: inherit; font: inherit }
.join-sound-panel input[type=file] { min-width: 0; width: 100%; max-width: 100%; font: inherit }
.join-sound-panel button:disabled { opacity: .5 }
</style>
