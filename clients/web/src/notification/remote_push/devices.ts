import { applicationKey, pushWorker, workerRequest, type WorkerState } from './bridge'
import { notificationInstance } from './registration'
export interface Device { id: string; instance_id: string; generation: number; state: string; transport: string; namespace: string; expires_at: string;session_ref: string }
export interface Capabilities { version: 1; account_id: string; origin: string; installation_id: string; namespace: string; operator_enabled: boolean; web_push_available: boolean; vapid_public_key: string;session_ref: string }
export class DeviceClient {
  private current = true
  private state: WorkerState | null = null
  private registration: ServiceWorkerRegistration | null = null
  device: Device | null = null
  constructor(readonly account: string, readonly capability: Capabilities, private request: typeof fetch = fetch) {
    if (capability.version !== 1 || capability.account_id !== account || capability.origin !== location.origin) throw new Error('Аккаунт или сервер изменился. Откройте приложение заново.')
    const port = request; this.request = (input, options = {}) => port(input, { ...options, headers: { ...options.headers, 'X-Notification-Account': account } })
  }
  get active() { return this.current && this.device?.state === 'active' && this.state?.active === true }
  get scope() { return JSON.stringify([location.origin, this.capability.installation_id, this.account,this.capability.session_ref]) }
  async restore() {
    if (!this.capability.web_push_available || !('serviceWorker' in navigator)) return
    this.registration = await navigator.serviceWorker.getRegistration('/') ?? null
    if (!this.registration?.active || !this.current) return
    const { record } = await workerRequest(this.registration, { type: 'READ' })
    if (!this.current || !record?.active) return
    if (record.scope !== this.scope) { await workerRequest(this.registration, { type: 'CLEAR', scope: record.scope, expectedEpoch: record.epoch }); return }
    const devices = await this.list()
    if (!this.current) return
    const device = devices.find(d => d.id === record.binding && d.session_ref === this.capability.session_ref && d.generation === record.generation && d.state === 'active' && Date.parse(d.expires_at) > Date.now())
    if (device) {
      this.device = device; this.state = record
      if (Notification.permission !== 'granted') { await this.clear(); return }
      const subscription = await this.registration.pushManager.getSubscription()
      if (!this.current) return
      if (!subscription || record.refresh_requested || await subscriptionHash(subscription) !== record.address_hash) await this.enable(false)
    }
    else await workerRequest(this.registration, { type: 'CLEAR', scope: record.scope, expectedEpoch: record.epoch })
  }
  async list(): Promise<Device[]> {
    const response = await this.request('/api/v1/notification-devices', { credentials: 'same-origin' })
    if (!response.ok) throw new Error('Не удалось получить устройства.')
    const body = await response.json(); if (body.version !== 1 || !Array.isArray(body.devices)) throw new Error('Некорректный список устройств.')
    return body.devices
  }
  async enable(askPermission = true) {
    if (!this.current || !this.capability.web_push_available) throw new Error('Сервер не настроил фоновую доставку.')
    if ((askPermission ? await Notification.requestPermission() : Notification.permission) !== 'granted') throw new Error('Разрешите уведомления в настройках браузера.')
    if (!this.current) return
    const registration = await pushWorker(); if (!this.current) return; this.registration = registration
    if (!(await workerRequest(registration, { type: 'RECONCILE' })).ok) throw new Error('Очистка предыдущей подписки не завершена. Проверьте сеть и повторите включение.')
    const before = await workerRequest(registration, { type: 'READ' }); if (!this.current) return
    const subscription = await registration.pushManager.getSubscription() ?? await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: applicationKey(this.capability.vapid_public_key) })
    if (!this.current) return
    const instance = this.device?.instance_id ?? notificationInstance(this.scope)
    const known = await this.list(); if (!this.current) return
    const old = known.find(d => d.instance_id === instance && d.session_ref === this.capability.session_ref) ?? this.device
    const webSubscription = subscription.toJSON()
    const response = await this.request('/api/v1/notification-devices' + (old ? '/' + old.id : ''), { method: old ? 'PUT' : 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ instance_id: instance, expected_generation: old?.generation ?? 0, transport: 'web_push', namespace: this.capability.namespace, permission: 'granted', consent_version: 1, subscription: { endpoint: webSubscription.endpoint, keys: webSubscription.keys } }) })
    if (!response.ok) throw new Error(response.status === 409 ? 'Привязка изменилась. Обновите список устройств.' : 'Не удалось зарегистрировать устройство.')
    const result = await response.json()
    if (!this.current || result.account_id !== this.account || result.device?.state !== 'active') return
    const address_hash = await subscriptionHash(subscription); if (!this.current) return
    const changed = await workerRequest(registration, { type: 'SET', expectedEpoch: before.record?.epoch ?? 0, state: { scope: this.scope, binding: result.device.id, generation: result.device.generation, active: true, address_hash } })
    if (!changed.ok || !this.current) throw new Error('Профиль изменился во время регистрации. Повторите включение.')
    this.state = changed.record ?? null; this.device = result.device
  }
  async revoke(device: Device) {
    const response = await this.request('/api/v1/notification-devices/' + encodeURIComponent(device.id), { method: 'DELETE', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ expected_generation: device.generation }) })
    if (!response.ok) throw new Error('Не удалось отозвать устройство. Обновите список.')
    if (device.id === this.device?.id) await this.clear()
  }
  async clear() {
    const state = this.state; this.state = null; this.device = null
    if (state && this.registration) {
      await workerRequest(this.registration, { type: 'CLEAR', scope: state.scope, expectedEpoch: state.epoch })
    }
  }
  cancel() { this.current = false }
}
async function subscriptionHash(subscription: PushSubscription) {
  const value = subscription.toJSON()
  const bytes = new TextEncoder().encode(JSON.stringify([value.endpoint, value.keys?.p256dh, value.keys?.auth]))
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), b => b.toString(16).padStart(2, '0')).join('')
}
