import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

import { loadPermissions, type PermissionSnapshot } from './permission_client'
import type { PermissionKey } from './permission_keys'

export const usePermissionStore = defineStore('effective-permissions', () => {
  const snapshot = ref<PermissionSnapshot | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  let generation = 0
  let activeAccount = ''
  let inFlight: Promise<void> | null = null
  let timer: ReturnType<typeof setInterval> | null = null
  let lastLoadedAt = 0

  const role = computed(() => snapshot.value?.role ?? null)
  function allows(permission: PermissionKey): boolean { return snapshot.value?.permissions[permission] === true }

  async function refresh(): Promise<void> {
    if (!activeAccount) return
    if (inFlight) return inFlight
    const requestGeneration = generation
    loading.value = true; error.value = null
    let task!: Promise<void>
    task = (async () => {
      try {
        const next = await loadPermissions()
        if (generation !== requestGeneration || next.accountId !== activeAccount) return
        snapshot.value = next; lastLoadedAt = Date.now()
      } catch (cause) {
        if (generation === requestGeneration) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить разрешения.'
      } finally {
        if (generation === requestGeneration) loading.value = false
        if (inFlight === task) inFlight = null
      }
    })()
    inFlight = task
    return task
  }

  async function refreshRealtime(): Promise<void> {
    if (!activeAccount) return
    generation++; inFlight = null
    const ownGeneration = generation
    await refresh()
    if (generation === ownGeneration && error.value) throw new Error(error.value)
  }

  function onFocus(): void { if (Date.now() - lastLoadedAt > 15_000) void refresh() }
  function start(accountId: string): void {
    stop(); activeAccount = accountId; generation++; void refresh()
    window.addEventListener('focus', onFocus); timer = setInterval(() => { if (!document.hidden) void refresh() }, 60_000)
  }
  function stop(): void {
    generation++; activeAccount = ''; snapshot.value = null; error.value = null; loading.value = false; lastLoadedAt = 0
    window.removeEventListener('focus', onFocus); if (timer) clearInterval(timer); timer = null; inFlight = null
  }

  return { snapshot, loading, error, role, allows, refresh, refreshRealtime, start, stop }
})
