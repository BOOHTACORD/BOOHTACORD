<script setup lang="ts">
import { computed, ref } from 'vue'
import type { BrowserSystemActivity } from './browser'

const props = defineProps<{ activity: BrowserSystemActivity }>()
const enabled = computed(() => props.activity.enabled.value)
const busy = ref(false), denied = ref(false)
async function toggle() {
  denied.value = false
  if (enabled.value) { props.activity.disable(); return }
  busy.value = true
  try { denied.value = !await props.activity.enable() } finally { busy.value = false }
}
</script>

<template>
  <section v-if="activity.available" class="profile-panel profile-system-activity" aria-labelledby="system-activity-title">
    <h2 id="system-activity-title">Активность компьютера</h2>
    <p>С разрешения браузера может учитываться работа за компьютером вне приложения. Точность зависит от браузера и фоновых ограничений. Без разрешения учитываются действия в приложении и речь.</p>
    <button class="profile-secondary-button" type="button" :aria-pressed="enabled" :disabled="busy" @click="toggle">
      Учитывать активность всего компьютера: {{ enabled ? 'включено' : 'выключено' }}
    </button>
    <p v-if="denied" role="status">Не удалось получить разрешение браузера. Учитываются действия в приложении и речь.</p>
  </section>
</template>

<style scoped>
:global(.workspace-main-panel--profile .profile-settings) > .profile-system-activity {
  align-self: start;
  min-height: max-content;
  margin-top: 20px;
}
</style>
