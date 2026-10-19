<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'

const props = defineProps<{ disabled: boolean; setPressed: (pressed: boolean) => void }>()
const element = ref<HTMLButtonElement | null>(null)
const pressed = ref(false)
let pointerId: number | null = null

function updatePressed(next: boolean): void {
  if (pressed.value === next) return
  pressed.value = next
  void props.setPressed(next)
}

function release(): void {
  const activePointer = pointerId
  pointerId = null
  updatePressed(false)
  if (activePointer !== null && element.value?.hasPointerCapture(activePointer)) {
    element.value.releasePointerCapture(activePointer)
  }
}

function onPointerDown(event: PointerEvent): void {
  if (props.disabled || pointerId !== null || !event.isPrimary || (event.pointerType === 'mouse' && event.button !== 0)) return
  event.preventDefault()
  pointerId = event.pointerId
  try { element.value?.setPointerCapture(event.pointerId) } catch { /* synthetic and interrupted pointers may not be capturable */ }
  updatePressed(true)
}

function onPointerEnd(event: PointerEvent): void {
  if (pointerId === null || event.pointerId !== pointerId) return
  release()
}

function onClick(event: MouseEvent): void {
  // VoiceOver/TalkBack and keyboard activation can synthesize a click without a pointer hold.
  if (event.detail !== 0 || props.disabled) return
  updatePressed(true)
  window.setTimeout(() => updatePressed(false), 120)
}

function releaseIfHidden(): void {
  if (document.visibilityState !== 'visible') release()
}

watch(() => props.disabled, disabled => { if (disabled) release() })
window.addEventListener('blur', release)
document.addEventListener('visibilitychange', releaseIfHidden)
onBeforeUnmount(() => {
  release()
  window.removeEventListener('blur', release)
  document.removeEventListener('visibilitychange', releaseIfHidden)
})
</script>

<template>
  <button
    ref="element"
    type="button"
    :disabled="disabled"
    :aria-label="pressed ? 'Говорите' : 'Удерживайте, чтобы говорить'"
    :aria-pressed="pressed"
    :style="pressed ? { color: 'var(--gc-on-danger)', backgroundColor: 'var(--gc-danger-solid)' } : undefined"
    data-testid="touch-ptt-button"
    @pointerdown="onPointerDown"
    @pointerup="onPointerEnd"
    @pointercancel="onPointerEnd"
    @lostpointercapture="onPointerEnd"
    @blur="release"
    @click="onClick"
  >
    <svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/></svg>
  </button>
</template>
