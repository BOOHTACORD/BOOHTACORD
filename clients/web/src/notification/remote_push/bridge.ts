export interface WorkerState { epoch: number; scope: string; binding?: string; generation?: number; active: boolean; pending_revoke?: boolean; clearing?: boolean; address_hash?: string; refresh_requested?: boolean }
export async function pushWorker(): Promise<ServiceWorkerRegistration> {
  if (!globalThis.isSecureContext || !('serviceWorker' in navigator) || !('PushManager' in globalThis)) throw new Error('Фоновые уведомления недоступны в этом браузере.')
  const registration = await navigator.serviceWorker.register('/notification-sw.js', { scope: '/', updateViaCache: 'none' })
  if (registration.active) return registration
  const worker = registration.installing ?? registration.waiting
  if (!worker) throw new Error('Обработчик уведомлений пока не готов.')
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => { worker.removeEventListener('statechange', changed); reject(new Error('Обработчик уведомлений пока не готов.')) }, 10000)
    function changed() { if (worker!.state === 'activated') { clearTimeout(timer); worker!.removeEventListener('statechange', changed); resolve() } }
    worker.addEventListener('statechange', changed); changed()
  })
  return registration
}
export async function workerRequest(registration: ServiceWorkerRegistration, input: Record<string, unknown>): Promise<{ ok: boolean; record?: WorkerState | null }> {
  const worker = registration.active
  if (!worker) throw new Error('Обработчик уведомлений пока не готов.')
  return await new Promise((resolve, reject) => {
    const channel = new MessageChannel()
    const timer = setTimeout(() => { channel.port1.close(); reject(new Error('Нет ответа обработчика уведомлений.')) }, 3000)
    channel.port1.onmessage = ({ data }) => { clearTimeout(timer); channel.port1.close(); resolve(data) }
    worker.postMessage(input, [channel.port2])
  })
}
export function applicationKey(value: string): Uint8Array<ArrayBuffer> {
  const raw = atob(value.replaceAll('-', '+').replaceAll('_', '/'))
  if (raw.length !== 65 || raw.charCodeAt(0) !== 4) throw new Error('Сервер не настроил ключ уведомлений.')
  return Uint8Array.from(raw, c => c.charCodeAt(0))
}
