import { defineStore } from 'pinia'
import { ref,onScopeDispose } from 'vue'
import { createNotificationPreferencesClient, PreferenceError, type Settings, type Snapshot, type Override } from './client'
import { previewLegacyPreferences } from './migration'
import { DeviceClient, type Device, type Capabilities } from '../remote_push/devices'
import type { ConversationKind, Preference } from '../conversation_preferences/policy'
export const useServerNotifications = defineStore('server-notifications', () => {
  const snapshot = ref<Snapshot | null>(null), capability = ref<Capabilities | null>(null)
  const error = ref(''), busy = ref(false), status = ref('Не включено на этом устройстве'), devices = ref<Device[]>([])
  const hint = ref(''), preview = ref<ReturnType<typeof previewLegacyPreferences> | null>(null)
  const currentBinding = ref('')
  let generation = 0, account = '', driver: DeviceClient | null = null
  let client = createNotificationPreferencesClient()
  async function start(id: string) {
    stop(); const version = generation; account = id; client = createNotificationPreferencesClient(undefined,id)
    try {
      const value = await client.load(); if (version !== generation || !value) return
      const response = await fetch('/api/v1/notification-devices/capabilities', { credentials: 'same-origin' })
      if (!response.ok) throw new Error('Не удалось проверить транспорт уведомлений.')
      const caps = await response.json() as Capabilities
      if (version !== generation || caps.account_id !== id || caps.origin !== location.origin) return
      snapshot.value = value; capability.value = caps
      preview.value = previewLegacyPreferences(localStorage, id)
      driver = new DeviceClient(id, caps); await driver.restore()
      if (version !== generation) return
      currentBinding.value = driver.active ? driver.device!.id : '';status.value = driver.active ? 'Активно на этом устройстве' : caps.web_push_available ? 'Не включено на этом устройстве' : 'Оператор не настроил фоновую доставку'
      const list=await driver.list();if(version===generation)devices.value=list
    } catch (cause) { if (version === generation) error.value = cause instanceof Error ? cause.message : 'Сервер недоступен.' }
  }
  function stop() { generation++; busy.value = false;currentBinding.value=''; driver?.cancel(); driver = null; account = ''; snapshot.value = null; capability.value = null; devices.value = []; hint.value = ''; error.value = '' }
  async function run(action: () => Promise<void>) {
    if (busy.value) return; busy.value = true; error.value = ''; const version = generation
    try { await action() } catch (cause) {
      if (version !== generation) return
      error.value = cause instanceof PreferenceError && cause.status === 409 ? 'Настройки изменились на другом устройстве. Показан актуальный выбор сервера.' : cause instanceof Error ? cause.message : 'Не удалось сохранить.'
      if (cause instanceof PreferenceError && cause.status === 409) { const latest=await client.load();if(version===generation)snapshot.value=latest }
    } finally { if (version === generation) busy.value = false }
  }
  async function save(change: (settings: Settings) => void) {
    const before = snapshot.value; if (!before) return; const version = generation
    await run(async () => { const settings = JSON.parse(JSON.stringify(before.settings)) as Settings; change(settings); const saved = await client.save(settings, before.settings.revision); if (version === generation) snapshot.value = saved })
  }
  async function reload() { const version = generation; await run(async () => { const value = await client.load(); if (version === generation) snapshot.value = value }) }
  async function enableDevice() {
    const current = driver; const version = generation
    await run(async () => { if (!current) return; await current.enable(); if (version !== generation) return;currentBinding.value=current.active?current.device!.id:''; status.value = current.active ? 'Активно на этом устройстве' : 'Регистрация не завершена'; devices.value = await current.list() })
  }
  async function revoke(device: Device) {
    const current = driver; const version = generation
    await run(async () => { if (!current) return; await current.revoke(device); if (version !== generation) return;currentBinding.value=current.active?current.device!.id:''; devices.value = await current.list(); status.value = current.active ? 'Активно на этом устройстве' : 'Не включено на этом устройстве' })
  }
  async function clearDevice() { const current = driver; current?.cancel(); await current?.clear().catch(() => {}) }
  async function importPreview() {
    const value = preview.value, before = snapshot.value; if (!value || !before || value.errors.length || before.settings.imported) return
    const version = generation
    await run(async () => { const saved = await client.importExplicit(value.overrides, value.local_disabled, before.settings.revision); if (version === generation) snapshot.value = saved })
  }
  function preference(kind: ConversationKind, id: string): Preference {
    const settings = snapshot.value?.settings
    const chosen = settings?.overrides.find(o => o.kind === kind && o.id === id) ?? (kind === 'CHANNEL' ? settings?.text : settings?.dm)
    return { mode: chosen?.mode ?? 'mentions', pausedUntil: chosen?.paused_until ? Date.parse(chosen.paused_until) : 0 }
  }
  async function setPreference(kind: ConversationKind, id: string, value: Preference) {
    await save(settings => { const override: Override = { kind, id, mode: value.mode, paused_until: value.pausedUntil ? new Date(value.pausedUntil).toISOString() : null }; settings.overrides = [...settings.overrides.filter(o => o.kind !== kind || o.id !== id), override] })
  }
  onScopeDispose(()=>{void clearDevice();stop()})
  return { snapshot, capability, error, busy, status, devices, hint, preview,currentBinding, start, stop, save, reload, enableDevice, revoke, clearDevice, importPreview, preference, setPreference }
})
