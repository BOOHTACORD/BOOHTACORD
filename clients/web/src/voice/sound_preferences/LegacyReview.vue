<script setup lang="ts">
import { legacySoundReview as legacy, voiceSoundPreferences as prefs } from '../sound_playback/runtime'
async function choose(quiet: boolean) {
  if (quiet) { await prefs.patch({ enabled:false }); if (prefs.unsynchronised.value) return }
  legacy.acknowledge()
}
</script>
<template>
  <aside v-if="legacy.blocked.value" role="status">
    <p>На этом устройстве были выключены старые звуки. Выберите настройки для текущего аккаунта.</p>
    <button type="button" :disabled="!prefs.ready.value" @click="choose(true)">Оставить выключенными</button>
    <button type="button" :disabled="!prefs.ready.value" @click="choose(false)">Использовать настройки аккаунта</button>
    <p v-if="legacy.failed.value">Не удалось сохранить выбор на устройстве.</p>
  </aside>
</template>
