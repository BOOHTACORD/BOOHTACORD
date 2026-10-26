import { defineStore } from 'pinia'
import { onScopeDispose, ref, watch } from 'vue'
import { createSupportOpener } from '../support/open'
import { noSupport, type SupportContact } from '../support/contact'
import { loadDirectNavigation } from './direct_message_navigation_client'
import { telemetrySession } from '../telemetry/action_scope/session'
import { requestFailureMessage } from '../request_feedback'

import {
  type DirectMessageListItem,
  type DirectMessageRequest,
} from './direct_message_client'
import { createDirectMessageHistory } from './direct_message_history'
import { createDirectMessageMessageActions } from './direct_message_message_actions'
import { type PendingDirectMessageSend } from './direct_message_pending'

export const useDirectMessageStore = defineStore('direct-messages', () => {
  const directMessages = ref<DirectMessageListItem[]>([])
  const supportContact=ref<SupportContact>({...noSupport})
  const supportChanged=ref(false)
  const pending = new Map<string, PendingDirectMessageSend>()
  const retries = new Map<string, string>()
  function acknowledge(id: string): void {
    pending.delete(id)
    for (const [key, value] of retries) if (value === id) retries.delete(key)
  }
  const { close, directMessageId, messages, nextCursor, loadingHistory, olderLoading, historyLoaded, error, retryableError, olderError, open, refreshHistory, loadOlder, refreshMessage, refreshMessages } = createDirectMessageHistory(pending, acknowledge)
  const deletedMessageIds = ref<string[]>([])
  watch(directMessageId, () => { deletedMessageIds.value = [] })
  const loadingNavigation = ref(false)
  const sending = ref(false)
  let navigationSequence = 0
  const actions = createDirectMessageMessageActions({ directMessageId, error, messages, sending, pending, retries, acknowledge })

  function applyDeletedHint(targetDirectMessageId: string, messageId: string): void {
    if (directMessageId.value !== targetDirectMessageId || !messageId) return
    if (!deletedMessageIds.value.includes(messageId)) deletedMessageIds.value = [...deletedMessageIds.value, messageId]
    messages.value = messages.value.map(message => message.id === messageId && !message.deleted
      ? { ...message, body: '', deleted: true, attachments: [], mentionUserIds: [] } : message)
  }

  async function remove(messageId: string, request?: DirectMessageRequest): Promise<boolean> {
    const target = directMessageId.value
    const removed = await actions.remove(messageId, request)
    if (removed && target) applyDeletedHint(target, messageId)
    return removed
  }

  async function refreshNavigation(request?: DirectMessageRequest): Promise<void> {
    const sequence = ++navigationSequence
    loadingNavigation.value = true
    error.value = null
    try {
      const loaded = await loadDirectNavigation(request)
      if (sequence === navigationSequence) {
       if(supportContact.value.accountId && loaded.supportContact.state==='available' && supportContact.value.accountId!==loaded.supportContact.accountId) supportChanged.value=true
       directMessages.value = loaded.items;supportContact.value=loaded.supportContact
      }
    } catch (cause) {
      if (sequence === navigationSequence) { supportContact.value=supportContact.value.mode==='product'?{...supportContact.value,state:'unavailable'}:{state:'unavailable',revision:0};error.value = requestFailureMessage(cause, 'Не удалось загрузить список личных сообщений.') }
    } finally {
      if (sequence === navigationSequence) loadingNavigation.value = false
    }
  }

  const support=createSupportOpener({refresh:refreshNavigation,contact:()=>supportContact.value,has:(id)=>directMessages.value.some(item=>item.id===id)})
  onScopeDispose(telemetrySession.onReset(()=>{navigationSequence++;supportContact.value={...noSupport};supportChanged.value=false;directMessages.value=[];support.invalidate()}))
  return {
    supportContact,supportChanged,supportOpening:support.supportOpening,supportNotice:support.supportNotice,openSupport:support.openSupport,
    close,
    applyDeletedHint,
    directMessageId,
    directMessages,
    deletedMessageIds,
    error,
    loadingHistory,
    olderLoading,
    historyLoaded,
    retryableError,
    olderError,
    loadOlder,
    loadingNavigation,
    messages,
    nextCursor,
    open,
    ...actions,
    remove,
    refreshHistory,
    refreshMessage,
    refreshMessages,
    refreshNavigation,
    sending,
  }
})
