<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, useId } from 'vue'
import { containModalTab } from '../accessibility/modal_tab_focus'

import { useDirectMessageCandidateStore } from './direct_message_candidate_store'

const emit = defineEmits<{ open: [directMessageId: string] }>()
const props = withDefaults(defineProps<{ prominent?: boolean }>(), { prominent: false })
const store = useDirectMessageCandidateStore()
const visible = ref(false)
const dialog = ref<HTMLDialogElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)
const closeButton = ref<HTMLButtonElement | null>(null)
const titleId = useId()
let generation = 0

async function show(): Promise<void> {
  if (visible.value) return
  visible.value = true
  const ticket = ++generation
  await nextTick()
  if (!visible.value || ticket !== generation) return
  dialog.value?.showModal()
  closeButton.value?.focus()
  void store.refresh()
}
function hide(): void {
  if (!visible.value) return
  generation++
  dialog.value?.close()
  visible.value = false
  void nextTick(() => { if (trigger.value?.isConnected) trigger.value.focus({ preventScroll: true }) })
}
function containKeys(event: KeyboardEvent): void {
  if (event.key === 'Escape') event.stopPropagation()
  containModalTab(event, dialog.value)
  if (event.key === 'Tab' && document.activeElement instanceof HTMLElement && dialog.value?.contains(document.activeElement)) {
    document.activeElement.scrollIntoView({ block: 'nearest', inline: 'nearest' })
  }
}
function dismissOutside(event: MouseEvent): void {
  if (event.target !== dialog.value || !dialog.value) return
  const box = dialog.value.getBoundingClientRect()
  if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) hide()
}
function refresh(): void { void store.refresh() }
async function choose(participantId: string): Promise<void> {
  const ticket = generation
  const directMessageId = await store.open(participantId)
  if (!directMessageId || !visible.value || ticket !== generation) return
  hide()
  emit('open', directMessageId)
}
onBeforeUnmount(() => { generation++; dialog.value?.close() })
</script>

<template>
  <button
    ref="trigger"
    class="channel-button direct-message-start-button"
    :class="{ 'direct-message-start-button--prominent': props.prominent }"
    type="button"
    aria-label="Начать диалог"
    aria-haspopup="dialog"
    :aria-expanded="visible"
    @click="show"
  >
    <span aria-hidden="true">＋</span>
    <span v-if="props.prominent">Начать диалог</span>
  </button>
  <Teleport to="body">
  <dialog v-if="visible" ref="dialog" class="dm-starter-dialog" aria-modal="true" :aria-labelledby="titleId" @cancel.prevent="hide" @close="hide" @click="dismissOutside" @keydown="containKeys">
    <header class="starter-header">
      <h3 :id="titleId">Новый личный диалог</h3>
      <button ref="closeButton" type="button" aria-label="Закрыть выбор участника" @click="hide">×</button>
    </header>
    <p v-if="store.loading" class="empty-category" aria-live="polite">Загружаем участников…</p>
    <p v-if="store.error" class="empty-category state-error" role="alert">{{ store.error }}</p>
    <p v-else-if="!store.loading && !store.candidates.length" class="empty-category">Нет доступных участников.</p>
    <div v-if="store.candidates.length" class="candidate-list">
      <button v-for="candidate in store.candidates" :key="candidate.id" class="channel-button" type="button" :disabled="store.opening" @click="choose(candidate.id)">
        {{ candidate.displayName }}
      </button>
    </div>
    <button v-if="store.error" class="channel-button" type="button" :disabled="store.loading" @click="refresh">Обновить список</button>
    <button v-if="store.nextAfter" class="channel-button" type="button" :disabled="store.loading || store.opening" @click="store.loadNext()">Загрузить ещё</button>
  </dialog>
  </Teleport>
</template>
