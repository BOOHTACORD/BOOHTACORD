<script setup lang="ts">
import { browserScreenCaptureCapabilities } from './screen_capture_capabilities'

defineProps<{ bandwidthEstimate?: string; updating?: boolean }>()
const capabilities = browserScreenCaptureCapabilities()
const video = capabilities.video === 'available' ? 'доступен в браузере' : 'недоступен в этом браузере'
</script>

<template>
  <div class="screen-share-capability-summary">
    <details class="screen-share-capabilities__details">
      <summary>Возможности и ограничения источника</summary>
      <p v-if="!updating" class="screen-share-capabilities__availability">Поддержка видео до выбора источника: {{ video }}</p>
      <p class="screen-share-capabilities__note">Для 1440p доступно до 30 FPS; сценарий выбирается отдельно. Суммарный лимит двух слоёв — {{ bandwidthEstimate ?? 'нет данных' }}; это не гарантированный сетевой расход.</p>
      <p v-if="updating" class="screen-share-capabilities__note">При ухудшении сети качество может временно снижаться. Приоритет — голос.</p>
      <dl class="screen-share-capabilities">
        <div><dt>Просмотр</dt><dd>Доступен в голосовой комнате</dd></div>
        <div><dt>Поддержка до выбора источника</dt><dd>Видео: {{ video }}</dd></div>
        <div><dt>Звук до выбора источника</dt><dd>Неизвестно</dd></div>
      </dl>
      <p class="screen-share-capabilities__note">
        Звук определяется после выбора источника по фактически полученной дорожке; выбранный источник может не передать аудио. Игровой звук не гарантируется.
      </p>
    </details>
  </div>
</template>
