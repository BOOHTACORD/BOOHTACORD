<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useUpdateStore } from './update_store'

const updates = useUpdateStore()
const dialog = ref<HTMLDialogElement | null>(null)
const action = ref<HTMLButtonElement | null>(null)
let previousFocus: HTMLElement | null = null
let app: HTMLElement | null = null
let wasInert = false
onMounted(async () => {
  previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
  app = document.getElementById('app'); wasInert = app?.inert ?? false
  if (app) app.inert = true
  dialog.value?.showModal()
  await nextTick(); action.value?.focus()
})
onBeforeUnmount(() => {
  dialog.value?.close()
  if (app) app.inert = wasInert
  if (previousFocus?.isConnected) previousFocus.focus()
})
</script>

<template>
  <Teleport to="body">
    <dialog ref="dialog" class="required-update" aria-labelledby="required-update-title" @cancel.prevent>
      <h1 id="required-update-title">Требуется обновление</h1>
      <p>Эта версия приложения больше не поддерживается. Обновите BOOHTACORD, чтобы продолжить.</p>
      <p v-if="updates.policy?.target?.summary">{{ updates.policy.target.summary }}</p>
      <p v-if="updates.error" role="alert">{{ updates.error }}</p>
      <button ref="action" type="button" @click="updates.apply">Обновить страницу</button>
    </dialog>
  </Teleport>
</template>

<style scoped>
.required-update { max-width: min(30rem, calc(100vw - 2rem)); max-height: calc(100vh - 2rem); overflow: auto; border: 1px solid #57519b; border-radius: 12px; padding: 24px; color: #f3f3fa; background: #20222e; }
.required-update::backdrop { background: rgba(0, 0, 0, .72); }
.required-update h1 { font-size: 1.4rem; margin: 0 0 1rem; }
.required-update p { line-height: 1.5; }
.required-update button { min-height: 44px; border: 0; border-radius: 8px; padding: 0 18px; background: #5865f2; color: white; cursor: pointer; }
.required-update button:focus-visible { outline: 3px solid white; outline-offset: 3px; }
</style>
