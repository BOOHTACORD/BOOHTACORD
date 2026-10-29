<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { shouldOpenSearchShortcut } from './search_shortcut'
import { searchReturnFocusTarget } from './search_return_focus'

const props = defineProps<{ active: boolean }>()
const emit = defineEmits<{ open: []; close: [] }>()
const trigger = ref<HTMLButtonElement | null>(null)
let returnFocus: HTMLElement | null = null
function openSearch(): void { returnFocus = document.activeElement as HTMLElement | null; emit('open') }
function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && props.active) { emit('close'); return }
  if (shouldOpenSearchShortcut(event, trigger.value)) { event.preventDefault(); openSearch() }
}
watch(() => props.active, (active, wasActive) => {
  if (wasActive && !active) void nextTick(() => {
    searchReturnFocusTarget(returnFocus, trigger.value, document.body, document.documentElement)?.focus()
    returnFocus = null
  })
})
onMounted(() => window.addEventListener('keydown', onKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))
</script>

<template>
  <button ref="trigger" class="guild-search-button" type="button" :aria-expanded="active" aria-controls="search-aside-panel" aria-keyshortcuts="Control+K Meta+K" @click="active ? emit('close') : openSearch()"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5" /><path d="m16 16 5 5" /></svg><span>Поиск сообщений</span><kbd>Ctrl K</kbd></button>
</template>
