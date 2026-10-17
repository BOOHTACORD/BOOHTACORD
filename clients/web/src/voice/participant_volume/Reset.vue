<script setup lang="ts">
import { ref } from 'vue'
const props = defineProps<{ reset: () => Promise<void>; warning?: string | null }>()
const busy = ref(false)
async function reset(): Promise<void> { busy.value = true; try { await props.reset() } finally { busy.value = false } }
</script>
<template>
  <section class="audio-device-section">
    <button class="gc-button gc-button--secondary" type="button" :aria-busy="busy" :disabled="busy" @click="reset">Сбросить громкость участников и трансляций</button>
    <p>Возвращает громкость участников и демонстраций к 100% на этом устройстве.</p>
    <p v-if="warning" class="state state-error" role="status">{{ warning }}</p>
  </section>
</template>
