<script setup lang="ts">
import { computed, ref } from 'vue'

import type { TextMessageAttachment } from '../message_client'
import ProtectedImageViewer from '../ProtectedImageViewer.vue'

const props = defineProps<{
  attachment: TextMessageAttachment
  downloadUrl: string
  previewUrl: string
}>()

const failedPreview = ref(false)
const showPreview = computed(() => /\.(png|jpe?g|gif)$/i.test(props.attachment.originalName))
const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })

function byteLabel(sizeBytes: number): string {
  if (sizeBytes < 1_000) return `${numberFormat.format(sizeBytes)} Б`
  if (sizeBytes < 1_000_000) return `${numberFormat.format(sizeBytes / 1_000)} КБ`
  return `${numberFormat.format(sizeBytes / 1_000_000)} МБ`
}
</script>

<template>
  <li class="attachment-card-item">
    <div class="attachment-card" :class="{ 'attachment-card--image': showPreview && !failedPreview }">
      <ProtectedImageViewer
        v-if="showPreview"
        :name="props.attachment.originalName"
        :preview-url="props.previewUrl"
        :download-url="props.downloadUrl"
      >
        <img
          v-if="!failedPreview"
          class="attachment-card__preview"
          :src="props.previewUrl"
          alt=""
          @error="failedPreview = true"
        >
        <svg v-else class="attachment-card__file-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M7 3h7l4 4v14H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
          <path d="M14 3v5h5M9 13h6M9 17h6" />
        </svg>
      </ProtectedImageViewer>
      <svg v-else class="attachment-card__file-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M7 3h7l4 4v14H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
        <path d="M14 3v5h5M9 13h6M9 17h6" />
      </svg>
      <span class="attachment-card__details">
        <svg v-if="showPreview && !failedPreview" class="attachment-card__name-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M7 3h7l4 4v14H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
          <path d="M14 3v5h5" />
        </svg>
        <span class="attachment-card__name">{{ props.attachment.originalName }}</span>
        <span class="attachment-card__size">{{ byteLabel(props.attachment.sizeBytes) }}</span>
      </span>
      <a
        class="attachment-card__download"
        :href="props.downloadUrl"
        :aria-label="`Скачать ${props.attachment.originalName}, ${byteLabel(props.attachment.sizeBytes)}`"
        :title="`Скачать ${props.attachment.originalName}`"
        download
      >
        <svg class="attachment-card__download-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M12 3v12m-4-4 4 4 4-4M5 17v3h14v-3" />
        </svg>
      </a>
    </div>
  </li>
</template>

<style scoped>
.attachment-card__name-icon {
  width: 16px;
  height: 16px;
  flex: none;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.75;
  stroke-linecap: round;
  stroke-linejoin: round;
}
</style>
