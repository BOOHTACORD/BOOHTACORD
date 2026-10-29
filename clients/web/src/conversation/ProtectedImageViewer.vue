<script setup lang="ts">
import { nextTick, ref } from 'vue'
import { useProtectedImagePreview } from './protected_image_preview/use_protected_image_preview'

const props = defineProps<{ name: string; previewUrl: string; downloadUrl: string }>()

const dialog = ref<HTMLDialogElement | null>(null)
const closeButton = ref<HTMLButtonElement | null>(null)
const opener = ref<HTMLButtonElement | null>(null)
const { imageUrl, loading, unavailable, failed, loadPreview, cancelPreview } = useProtectedImagePreview(
  () => props.previewUrl, () => Boolean(dialog.value?.open),
)

async function open(): Promise<void> {
  if (dialog.value?.open) return
  opener.value = document.activeElement instanceof HTMLButtonElement
    ? document.activeElement
    : null
  dialog.value?.showModal()
  await nextTick()
  closeButton.value?.focus()
  void loadPreview()
}

function restoreFocus(): void {
  cancelPreview()
  if (opener.value?.isConnected) opener.value.focus()
  opener.value = null
}

function close(): void {
  if (dialog.value?.open) dialog.value.close()
  else restoreFocus()
}

function onCancel(event: Event): void {
  event.preventDefault()
  close()
}

function onDialogClick(event: MouseEvent): void {
  if (event.target !== dialog.value || !dialog.value) return
  const bounds = dialog.value.getBoundingClientRect()
  if (
    event.clientX < bounds.left || event.clientX > bounds.right ||
    event.clientY < bounds.top || event.clientY > bounds.bottom
  ) close()
}

</script>

<template>
  <button
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
    @close="restoreFocus"
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
