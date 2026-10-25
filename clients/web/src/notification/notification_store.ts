import { defineStore } from 'pinia'
import { ref, watch, type WatchStopHandle } from 'vue'

import { useTopologyStore } from '../channel/topology_store'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import type { RealtimeEvent } from '../realtime/realtime_client'
import { browserNotificationRuntime, createNotificationDelivery, type NotificationRuntime } from './notification_delivery'
import { addressedUnread, notificationCandidate, notificationTitle, unreadTotal } from './notification_policy'
import { createConversationNotificationController, defaultConversationPreference } from './conversation_preferences/controller'
import type { ConversationKind, Preference } from './conversation_preferences/policy'
import { guildProfile } from '../guild/profile/state'
import { useServerNotifications } from './server_preferences/state'

export const useNotificationStore = defineStore('notifications', () => {
  const remote = useServerNotifications()
  const topology = useTopologyStore()
  const directMessages = useDirectMessageStore()
  const available = ref(false)
  const enabled = ref(false)
  const permission = ref<NotificationPermission | 'unavailable'>('unavailable')
  const error = ref<string | null>(null)
  let delivery: ReturnType<typeof createNotificationDelivery> | null = null
  let stopTitleWatch: WatchStopHandle | null = null
  let originalTitle = ''
  let conversations:ReturnType<typeof createConversationNotificationController>|null=null
  const preferencesRevision=ref(0)
  const conversationPreference=(kind:ConversationKind,id:string):Preference=>{preferencesRevision.value;return remote.snapshot ? remote.preference(kind,id) : conversations?.get(kind,id) ?? defaultConversationPreference()}
  async function setConversationPreference(kind:ConversationKind,id:string,value:Preference):Promise<void> {
    error.value=null
    try {if(remote.snapshot) await remote.setPreference(kind,id,value);else await conversations?.set(kind,id,value)} catch(cause) {error.value=cause instanceof Error ? cause.message : 'Не удалось сохранить уведомления.'}
  }
  async function resetConversationPreferences():Promise<void> {
    error.value=null
    try {if(remote.snapshot) await remote.save(s=>{s.overrides=[]});else await conversations?.reset()} catch {error.value='Не удалось сбросить настройки уведомлений.'}
  }

  function refreshStatus(): void {
    try {
      available.value = delivery?.available() ?? false
      enabled.value = delivery?.enabled() ?? false
      permission.value = delivery?.permission() ?? 'unavailable'
    } catch {
      available.value = false
      enabled.value = false
      permission.value = 'unavailable'
    }
  }

  function start(accountID: string, runtime?: NotificationRuntime): void {
    stop()
    if (!runtime && typeof window !== 'undefined') void remote.start(accountID)
    const port=runtime ?? browserNotificationRuntime()
    delivery = createNotificationDelivery(accountID, port, () => guildProfile.name.value)
    conversations=createConversationNotificationController(accountID,port,()=>{preferencesRevision.value++})
    preferencesRevision.value++
    refreshStatus()
    if (typeof document === 'undefined') return
    originalTitle = document.title
    stopTitleWatch = watch(
      () => [unreadTotal(topology.topology, directMessages.directMessages), guildProfile.name.value] as const,
      ([count, name]) => { originalTitle = name; document.title = notificationTitle(name, count) },
      { immediate: true },
    )
  }

  function stop(): void {
    remote.stop()
    if (stopTitleWatch) { stopTitleWatch(); stopTitleWatch = null; document.title = originalTitle }
    delivery?.cancel()
    conversations?.cancel();conversations=null;preferencesRevision.value++
    delivery = null
    refreshStatus()
  }

  async function enable(): Promise<void> {
    if (!delivery) return
    error.value = null
    try { await delivery.enable() }
    catch { error.value = 'Не удалось включить уведомления. Проверьте настройки браузера.' }
    refreshStatus()
  }

  function disable(): void {
    error.value = null
    try { delivery?.disable() }
    catch { error.value = 'Не удалось отключить уведомления. Проверьте настройки браузера.' }
    refreshStatus()
  }

  function capture(event: RealtimeEvent): number | null {
    const previous = addressedUnread(event, topology.topology, directMessages.directMessages)
    return previous ?? (event.kind === 'direct_message.message_created' ? 0 : null)
  }

  async function deliver(event: RealtimeEvent, previousUnread: number | null): Promise<void> {
    if (remote.currentBinding) return
    if (!delivery || previousUnread === null || typeof document === 'undefined' || document.visibilityState !== 'hidden') return
    let body = notificationCandidate(event, topology.topology, directMessages.directMessages, previousUnread)
    if (!body || !enabled.value) return
    const currentDelivery = delivery
    const currentConversations=conversations, notice=await currentConversations?.prepare(event)
    if (!notice || delivery !== currentDelivery) return
    body=notice.body ?? body
    try { await delivery.deliver(event.eventId, body,()=>delivery===currentDelivery && document.visibilityState==='hidden' && Boolean(currentConversations?.allowed(event,notice.mentioned))) } catch { /* Keep realtime recovery independent. */ }
    refreshStatus()
  }

  return { available, enabled, permission, error, start, stop, enable, disable, refreshStatus, capture, deliver, conversationPreference, setConversationPreference, resetConversationPreferences }
})
