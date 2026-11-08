<script setup lang="ts">
import { legacySoundReview as legacy, voiceSoundPreferences as prefs } from '../sound_playback/runtime'
async function choose(quiet: boolean) {
  if (quiet) { await prefs.patch({ enabled:false }); if (prefs.unsynchronised.value) return }
  legacy.acknowledge()
}
</script>
<template>
  <aside class="legacy-sounds" v-if="legacy.blocked.value" role="status">
    <p>На этом устройстве были выключены старые звуки. Выберите настройки для текущего аккаунта.</p>
    <button type="button" :disabled="!prefs.ready.value" @click="choose(true)">Оставить выключенными</button>
    <button type="button" :disabled="!prefs.ready.value" @click="choose(false)">Использовать настройки аккаунта</button>
    <p v-if="legacy.failed.value">Не удалось сохранить выбор на устройстве.</p>
  </aside>
</template>

<style scoped>
.legacy-sounds { display: flex; flex-wrap: wrap; gap: 8px; margin-block: 12px }
.legacy-sounds p { flex-basis: 100%; margin: 0 }
.legacy-sounds button { min-height: 44px; padding: 8px 12px; border: 1px solid #434957; border-radius: 8px; background: #23262f; color: inherit; font: inherit; text-align: start }
.legacy-sounds button:disabled { opacity: .5 }
</style>
