<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { containModalTab } from '../accessibility/modal_tab_focus'

const props = defineProps<{ id: string; title: string; confirmLabel: string }>()
const dialog = ref<HTMLDialogElement | null>(null)
const message = ref('')
let answer: ((confirmed: boolean) => void) | null = null
let opener: HTMLElement | null = null
let lastClickedOpener: HTMLElement | null = null
let lastClickAt = 0

function rememberClickedOpener(event: MouseEvent): void {
  const target = event.target
  const candidate = target instanceof Element
    ? target.closest<HTMLElement>('button, input[type="button"], input[type="submit"], a[href], [role="button"], [tabindex]:not([tabindex="-1"])')
    : null
  if (candidate) {
    lastClickedOpener = candidate
    lastClickAt = performance.now()
  }
}

async function ask(text: string): Promise<boolean> {
  if (answer) return false
  const active = document.activeElement instanceof HTMLElement && document.activeElement !== document.body
    ? document.activeElement
    : null
  opener = active ?? (performance.now() - lastClickAt <= 1000 ? lastClickedOpener : null)
  message.value = text
  await nextTick()
  return new Promise<boolean>((resolve) => {
    answer = resolve
    try { dialog.value?.showModal() } catch { settle(false) }
    if (!dialog.value) settle(false)
  })
}

function settle(confirmed: boolean): void {
  if (!answer) return
  const resolve = answer
  answer = null
  if (dialog.value?.open) dialog.value.close()
  resolve(confirmed)
  if (!confirmed) void nextTick(() => { if (opener?.isConnected) opener.focus({ preventScroll: true }) })
}

onMounted(() => document.addEventListener('click', rememberClickedOpener, true))
onBeforeUnmount(() => settle(false))
onBeforeUnmount(() => document.removeEventListener('click', rememberClickedOpener, true))
function containKeys(event: KeyboardEvent): void {
  if (event.key === 'Escape') event.stopPropagation()
  containModalTab(event, dialog.value)
}

function cancel(): boolean {
  if (!answer) return false
  settle(false)
  return true
}
defineExpose({ ask, cancel })
</script>

<template>
  <dialog ref="dialog" class="admin-confirm-dialog" aria-modal="true" :aria-labelledby="`${props.id}-title`" :aria-describedby="`${props.id}-message`" @cancel.prevent="settle(false)" @close="settle(false)" @keydown="containKeys">
    <h3 :id="`${props.id}-title`">{{ title }}</h3>
    <p :id="`${props.id}-message`">{{ message }}</p>
    <div class="admin-confirm-actions">
      <button type="button" autofocus @click="settle(false)">Отмена</button>
      <button type="button" @click="settle(true)">{{ confirmLabel }}</button>
    </div>
  </dialog>
</template>
