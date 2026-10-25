import type { RealtimeEvent } from '../../realtime/realtime_client'
import { useServerNotifications } from '../server_preferences/state'
import { useMessageStore } from '../../conversation/message_store'
import { useDirectMessageStore } from '../../direct_message/direct_message_store'
let lastHint: { ref: string; generation: number } | null = null
export const latestNotificationHint = () => lastHint
export async function acceptNotificationHint(event: RealtimeEvent, account: string) {
  const store = useServerNotifications()
  if (event.kind === 'notification.preferences_changed') { await store.reload(); return true }
  if (event.kind !== 'notification.queued') return false
  const hint = event.payload
  if (typeof document === 'undefined' || document.visibilityState !== 'visible' || !document.hasFocus()) return true
  const binding = store.devices.find(d => d.id === hint.binding_ref && d.generation === hint.generation && d.state === 'active')
  if (!binding || !store.currentBinding || store.currentBinding !== binding.id) return true
  const direct = useDirectMessageStore(), text = useMessageStore()
  const current = hint.kind === 'DM' ? direct.directMessageId : direct.directMessageId ? null : text.channelId
  if (current !== hint.conversation_id) { store.hint = hint.kind === 'DM' ? 'Новое личное сообщение' : 'Новая активность в канале'; lastHint = { ref: String(hint.ref), generation: Number(hint.generation) } }
  await fetch('/api/v1/notification-references/presented', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json', 'X-Notification-Account': account }, body: JSON.stringify({ ref: hint.ref, generation: hint.generation }) }).catch(() => {})
  return true
}
