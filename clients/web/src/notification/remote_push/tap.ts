import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
interface Target { version: 1; kind: 'DM' | 'TEXT'; conversation_id: string; message_id: string }
interface Ports { account: string; ready(): boolean; navigate(target: Target): Promise<void> }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
export function useNotificationTap(ports: Ports) {
  const error = ref(''); let active = true, pending: { ref: string; generation: number } | null = null, busy = false
  async function drain() {
    if (!active || !ports.ready() || !pending || busy) return
    const input = pending; pending = null; busy = true; error.value = ''
    try {
      const response = await fetch('/api/v1/notification-references/resolve', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json', 'X-Notification-Account': ports.account }, body: JSON.stringify(input) })
      if (!response.ok) throw new Error('Уведомление недоступно для текущего аккаунта. Проверьте вход и выбранный сервер.')
      const target = await response.json() as Target
      if (target.version !== 1 || !['DM', 'TEXT'].includes(target.kind) || !uuid.test(target.conversation_id) || !uuid.test(target.message_id)) throw new Error('Сервер вернул некорректный переход.')
      if (active) await ports.navigate(target)
    } catch (cause) { if (active) error.value = cause instanceof Error ? cause.message : 'Не удалось открыть уведомление.' }
    finally { busy = false; if (active && pending) void drain() }
  }
  function accept(value: unknown) {
    if (!value || typeof value !== 'object') return
    const data = value as Record<string, unknown>
    if (typeof data.ref !== 'string' || !uuid.test(data.ref) || !Number.isSafeInteger(data.generation) || Number(data.generation) < 1) return
    pending = { ref: data.ref, generation: Number(data.generation) }; void drain()
  }
  function message(event: MessageEvent) {
    const worker = event.source as ServiceWorker | null
    if (!worker?.scriptURL || new URL(worker.scriptURL).origin !== location.origin || new URL(worker.scriptURL).pathname !== '/notification-sw.js') return
    if (event.data?.type === 'notification.open') accept(event.data)
  }
  onMounted(() => {
    navigator.serviceWorker?.addEventListener('message', message)
    if (location.hash.startsWith('#notification=')) {
      try { accept(JSON.parse(decodeURIComponent(location.hash.slice('#notification='.length)))) } catch { error.value = 'Некорректная ссылка уведомления.' }
      const url = new URL(location.href); url.hash = ''; history.replaceState(history.state, '', url)
    }
  })
  watch(ports.ready, () => void drain())
  onBeforeUnmount(() => { active = false; pending = null; navigator.serviceWorker?.removeEventListener('message', message) })
  return { error, accept }
}
