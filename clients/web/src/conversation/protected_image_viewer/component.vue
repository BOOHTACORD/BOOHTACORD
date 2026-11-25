<script setup lang="ts">
import { ref } from 'vue'
import { useProtectedImagePreview } from './preview'
import { useImageDialog } from './dialog'

const props = defineProps<{ name: string; previewUrl: string; downloadUrl: string }>()
const dialog = ref<HTMLDialogElement | null>(null)
const { imageUrl, loading, unavailable, failed, loadPreview, cancelPreview } = useProtectedImagePreview(
  () => props.previewUrl, () => Boolean(dialog.value?.open),
)
const { trigger, closeButton, open, close, onCancel, onDialogClick, onClosed, onKeydown } = useImageDialog(
  dialog, () => `${props.previewUrl}\n${props.downloadUrl}`, loadPreview, cancelPreview,
)
</script>

<template>
  <button
    ref="trigger"
    class="attachment-card__open"
    type="button"
    :aria-label="`Открыть изображение ${props.name}`"
    :title="`Открыть изображение ${props.name}`"
    @click="open"
  >
    <slot />
  </button>

  <dialog
    ref="dialog"
    class="attachment-image-dialog"
    :aria-label="`Просмотр изображения ${props.name}`"
    @cancel="onCancel"
    @click="onDialogClick"
    @close="onClosed"
    @keydown="onKeydown"
  >
    <header class="attachment-image-dialog__header">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6Z"/><path d="M14 2v6h6"/></svg>
      <h2>{{ props.name }}</h2>
      <a v-if="imageUrl && !failed" :href="props.downloadUrl" :download="props.name" class="attachment-image-dialog__download"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/></svg>Скачать</a>
      <button
        ref="closeButton"
        type="button"
        class="attachment-image-dialog__close"
        aria-label="Закрыть просмотр изображения"
        @click="close"
      >
        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>
      </button>
    </header>
    <div class="attachment-image-dialog__content" aria-live="polite" :aria-busy="loading">
      <p v-if="loading" class="attachment-image-dialog__status">Загружаем изображение…</p>
      <img
        v-else-if="imageUrl && !failed"
        :src="imageUrl"
        :alt="props.name"
        class="attachment-image-dialog__image"
        @error="failed = true"
      >
      <div v-else class="attachment-image-dialog__error" role="status">
        <span>{{ unavailable ? 'Вложение удалено или недоступно.' : 'Не удалось загрузить изображение.' }}</span>
        <button v-if="!unavailable" type="button" @click="loadPreview">Повторить</button>
      </div>
    </div>
    <footer class="attachment-image-dialog__footer">Изображение целиком · Масштаб по размеру окна</footer>
  </dialog>
</template>
