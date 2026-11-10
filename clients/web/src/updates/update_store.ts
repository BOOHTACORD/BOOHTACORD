import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

import { buildIdentity } from './build_identity'
import { fetchUpdatePolicy } from './client'
import { evaluateUpdate, requiresUpdate } from './evaluator'
import { controlledReload } from './safe_reload'
import { UpdateScheduler } from './scheduler'
import type { UpdatePolicy, UpdateResult } from './types'

const snoozeKey = (policy: UpdatePolicy) => `boohtacord:update:${location.origin}:web:browser:stable:${policy.target?.release_id}:${policy.target?.priority}`
type UpdateAttempt = { expectedRelease?: string; attemptedAt?: number }

export const useUpdateStore = defineStore('client-updates', () => {
  const checkStatus = ref<'idle'|'checking'|'ok'|'error'>('idle')
  const result = ref<UpdateResult | null>(null)
  const policy = ref<UpdatePolicy | null>(null)
  const stale = ref(false); const error = ref<string | null>(null)
  const preloadFailure = ref(false); const cooldownUntil = ref(0)
  const lastSuccessfulCheckAt = ref<Date | null>(null)
  const snoozeRevision = ref(0)
  let scheduler: UpdateScheduler | null = null

  const snoozed = () => policy.value ? Number(localStorage.getItem(snoozeKey(policy.value)) ?? 0) > Date.now() : false
  const required = computed(() => policy.value !== null && requiresUpdate(buildIdentity, policy.value, { os_version:'browser', arch:'any' }))
  const visible = computed(() => { void snoozeRevision.value; return preloadFailure.value || (result.value === 'update_available' && !snoozed()) })

  async function check(): Promise<void> {
    if (checkStatus.value === 'checking') return
    checkStatus.value = 'checking'; error.value = null
    try {
      const next = await fetchUpdatePolicy()
      if ((next.catalog_revision ?? 0) < (policy.value?.catalog_revision ?? 0)) { checkStatus.value = 'ok'; return }
      policy.value = next
      result.value = evaluateUpdate(buildIdentity, next, { os_version:'browser', arch:'any' })
      stale.value = false; checkStatus.value = 'ok'; lastSuccessfulCheckAt.value = new Date()
    } catch (cause) {
      stale.value = result.value !== null; checkStatus.value = 'error'
      error.value = cause instanceof Error ? cause.message : 'Не удалось проверить обновление.'
      throw cause
    }
  }

  function start(): void {
    let attempt: UpdateAttempt | null = null
    try { attempt = JSON.parse(sessionStorage.getItem('boohtacord:update-attempt') ?? 'null') as UpdateAttempt | null } catch { sessionStorage.removeItem('boohtacord:update-attempt') }
    if (attempt?.expectedRelease === buildIdentity.release_id) sessionStorage.removeItem('boohtacord:update-attempt')
    else if (attempt?.attemptedAt && Date.now()-attempt.attemptedAt < 10*60_000) error.value = 'Перезагрузка завершилась на прежней версии. Повторите позже.'
    if (!scheduler) { scheduler = new UpdateScheduler(check); scheduler.start() }
  }
  function dispose(): void { scheduler?.dispose(); scheduler = null }
  function manual(): void {
    if (Date.now() < cooldownUntil.value) return
    cooldownUntil.value = Date.now() + 5_000; scheduler?.manual() ?? void check().catch(() => {})
  }
  function later(): void {
    const current = policy.value; if (!current?.target || required.value) return
    const delay = current.target.priority === 'important' ? 15*60_000 : 2*60*60_000
    localStorage.setItem(snoozeKey(current), String(Date.now() + delay)); preloadFailure.value = false; snoozeRevision.value++
  }
  async function apply(): Promise<void> {
    try {
      const fresh = await fetchUpdatePolicy()
      if ((fresh.catalog_revision ?? 0) < (policy.value?.catalog_revision ?? 0)) throw new Error('Получен устаревший каталог обновлений.')
      policy.value = fresh
      result.value = evaluateUpdate(buildIdentity, fresh, { os_version:'browser', arch:'any' })
      if ((result.value !== 'update_available' && !required.value) || !fresh.target) return
      const response = await fetch('/build-info.json', { cache:'no-store', credentials:'omit' })
      const info = response.ok ? await response.json() as { release_id?:string } : null
      if (info?.release_id !== fresh.target.release_id) throw new Error('Файлы новой версии ещё не готовы.')
      await controlledReload(fresh.target.release_id)
    } catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось начать обновление.' }
  }
  function reportPreloadError(): void { preloadFailure.value = true }
  return { apply, buildIdentity, check, checkStatus, cooldownUntil, dispose, error, lastSuccessfulCheckAt, later, manual, policy, preloadFailure, reportPreloadError, required, result, stale, start, visible }
})
