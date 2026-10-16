<script setup lang="ts">
import { microphoneMeter, microphoneSettingsError } from './runtime'
</script>
<template>
  <p v-if="microphoneMeter.status === 'unsupported' || microphoneMeter.status === 'error'" role="alert">Обработка микрофона недоступна. Отправка звука выключена.</p>
  <p v-if="microphoneSettingsError" role="alert">{{ microphoneSettingsError }}</p>
  <p v-if="microphoneMeter.clipping" role="status">Перегрузка: уменьшите громкость микрофона.</p>
</template>
