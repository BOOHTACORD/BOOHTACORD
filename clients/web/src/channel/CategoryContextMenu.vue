<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import type { ChannelTopology, TopologyCategory } from './topology_client'
import type { PermissionValues } from '../authorization/permission_keys'
import { renameCategory } from './category_mutation_client'

const props = defineProps<{ topology: ChannelTopology; permissions?: PermissionValues }>()
const emit = defineEmits<{ createGlobal: []; createInCategory: [category: TopologyCategory]; deleteCategory: [category: TopologyCategory]; changed: [] }>()
const categoryMenu = ref<{ x: number; y: number; category: TopologyCategory } | null>(null)
const menuElement = ref<HTMLElement | null>(null)
const trigger = ref<HTMLElement | null>(null)
const menuError = ref('')

function open(event: MouseEvent, category: TopologyCategory): void {
  if (!props.permissions) return
  const categoryElement = event.currentTarget as HTMLElement
  const eventTarget = event.target
  trigger.value = eventTarget instanceof Element
    ? eventTarget.closest<HTMLElement>('button') ?? categoryElement.querySelector<HTMLElement>('.channel-category-disclosure')
    : categoryElement.querySelector<HTMLElement>('.channel-category-disclosure')
  categoryMenu.value = { x: Math.max(8, Math.min(event.clientX, innerWidth - 276)), y: Math.max(8, Math.min(event.clientY, innerHeight - 267)), category }
  menuError.value = ''
  void nextTick(() => menuElement.value?.querySelector<HTMLElement>('button:not(:disabled)')?.focus())
}
function close(restoreFocus = true): void {
  categoryMenu.value = null
  if (restoreFocus) void nextTick(() => trigger.value?.focus())
}
function dismissOnOutsidePointer(event: PointerEvent): void {
  if (!categoryMenu.value || !(event.target instanceof Node) || menuElement.value?.contains(event.target)) return
  close(false)
}
function dismissOnEscape(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || !categoryMenu.value) return
  event.preventDefault()
  event.stopPropagation()
  close()
}
onMounted(() => {
  document.addEventListener('pointerdown', dismissOnOutsidePointer, true)
  document.addEventListener('keydown', dismissOnEscape, true)
})
onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', dismissOnOutsidePointer, true)
  document.removeEventListener('keydown', dismissOnEscape, true)
})
async function rename(): Promise<void> {
  const target = categoryMenu.value?.category
  if (!target || !props.permissions?.['category.create']) return
  const name = window.prompt('Новое название раздела', target.name)?.trim()
  if (!name) return
  try { await renameCategory(target.id, name, props.topology.revision); close(); emit('changed') }
  catch (cause) { menuError.value = cause instanceof Error ? cause.message : 'Не удалось переименовать раздел.' }
}
function canCreate(): boolean { const p = props.permissions; return Boolean(p && (p['category.create'] || p['channel.text.create'] || p['channel.voice.create'])) }
defineExpose({ open })
</script>

<template>
  <div v-if="categoryMenu" ref="menuElement" class="category-context-menu" role="menu" :style="{ left: `${categoryMenu.x}px`, top: `${categoryMenu.y}px` }">
    <span class="category-context-caption">Раздел «{{ categoryMenu.category.name }}»</span>
    <button v-if="canCreate()" type="button" role="menuitem" @click="emit('createInCategory', categoryMenu.category); close()"><span class="category-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14" /></svg></span>Создать канал...</button>
    <button v-if="props.permissions?.['category.create']" type="button" role="menuitem" @click="emit('createGlobal'); close()"><span class="category-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h6l2 2h10v13H3V5Z" /></svg></span>Создать раздел...</button>
    <div class="category-context-separator" role="separator" />
    <button v-if="props.permissions?.['category.create']" type="button" role="menuitem" @click="rename"><span class="category-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="m16 3 5 5L8 21H3v-5L16 3ZM14 5l5 5" /></svg></span>Переименовать раздел...</button>
    <button v-if="props.permissions?.['category.delete']" type="button" role="menuitem" :disabled="categoryMenu.category.channels.length > 0" @click="emit('deleteCategory', categoryMenu.category); close()"><span class="category-context-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7" /></svg></span>Удалить раздел...</button>
    <p v-if="categoryMenu.category.channels.length > 0" class="category-context-hint">Сначала уберите каналы из раздела.</p><p v-if="menuError" role="alert">{{ menuError }}</p>
  </div>
</template>
