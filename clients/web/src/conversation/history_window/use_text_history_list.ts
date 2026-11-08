import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'
import type { CurrentSession } from '../../identity/current_session'
import { useAuthorDirectory } from '../../identity/author_directory'
import { useMessageStore } from '../message_store'
import type { TextMessage } from '../message_client'
import { createMessageLogAnnouncer } from '../message_log_announcement'
import { isHistoryNearBottom, newestServerMessageId, newServerMessageCount, shouldFollowNewestMessages } from '../new_message_jump'
import { navigateToReplyTarget } from '../reply_context_navigation'
import { buildTimeline } from './timeline'
import { useHistoryWindow } from './use'
import { provideHistoryEditors } from './editing_state/context'
import { draftMemoryEpoch } from '../draft_memory'
import { scrollToMessageTarget } from '../message_target_navigation'

type Callbacks = { viewportChange: () => void; replyContext: (messageId: string) => void }
export function useTextHistoryList(props: { channelId: string; session: CurrentSession | null }, emit: Callbacks, list: Ref<HTMLOListElement | null>) {
  const store = useMessageStore(), authors = useAuthorDirectory(), compact = ref(false)
  const editors = provideHistoryEditors(), editorVersion = ref(0)
  const timeline = computed(() => buildTimeline(store.messages, store.historyLoaded, Boolean(store.nextCursor), compact.value))
  const historyWindow = useHistoryWindow(timeline, list, computed(() => Boolean(store.nextCursor)), compact, editors.has)
  const scopeIdentity = computed(() => JSON.stringify([props.channelId, store.channelId, props.session?.accountId ?? null, draftMemoryEpoch()]))
  const historyScope = computed(() => `${scopeIdentity.value}:${editorVersion.value}`)
  watch([scopeIdentity, () => store.messages.length === 0], () => { historyWindow.clearPins(); editors.clear(); editorVersion.value++ }, { flush: 'sync' })
  onBeforeUnmount(() => { historyWindow.clearPins(); editors.dispose() })
  const announceNew = createMessageLogAnnouncer(), announcement = ref(''), jumpCount = ref(0)
  const latestServerId = computed(() => newestServerMessageId(store.messages))
  let targetNavigationDepth = 0
  let announcementVersion = 0
  watch([() => props.channelId, () => store.channelId, () => store.historyLoaded, () => store.messages, () => props.session?.accountId], async () => {
    const text = announceNew({ conversationId: props.channelId, loaded: store.historyLoaded && store.channelId === props.channelId,
      active: typeof document !== 'undefined' && document.visibilityState === 'visible', ownId: props.session?.accountId ?? '',
      messages: store.messages, displayName: (id) => authors.displayName(id) })
    const version = ++announcementVersion; announcement.value = ''
    if (!text) return
    await nextTick(); if (version === announcementVersion) announcement.value = text
  }, { immediate: true, flush: 'post' })
  onMounted(() => { if (list.value) list.value.scrollTop = list.value.scrollHeight; historyWindow.syncScroll(true); updateHistoryAnchor(); emit.viewportChange() })
  watch(() => props.channelId, async () => { jumpCount.value = 0; await nextTick(); if (list.value) list.value.scrollTop = list.value.scrollHeight; historyWindow.syncScroll(true); updateHistoryAnchor(); emit.viewportChange() })
  watch([() => store.historyLoaded, latestServerId], async ([loaded, newest], [wasLoaded, previous]) => {
    const viewport = list.value
    if (!newest || !viewport || store.channelId !== props.channelId) return
    if (targetNavigationDepth) {
      await nextTick()
      if (targetNavigationDepth) { emit.viewportChange(); return }
    }
    const nearBottom = isHistoryNearBottom(viewport), added = newServerMessageCount(store.messages, previous, wasLoaded)
    await nextTick()
    if (shouldFollowNewestMessages(store.messages, previous, wasLoaded, nearBottom)) { viewport.scrollTop = viewport.scrollHeight; historyWindow.syncScroll(true); jumpCount.value = 0 }
    else if (loaded) jumpCount.value += added
    emit.viewportChange()
  })
  const scrolledPending = new Set<string>()
  let pendingScope = ''
  watch([() => props.channelId, () => props.session?.accountId, () => store.messages], async ([channelId, accountId, messages]) => {
    if (channelId !== store.channelId) return
    if (pendingScope !== channelId) {
      pendingScope = channelId
      scrolledPending.clear()
      for (const message of messages) if (message.sendStatus) scrolledPending.add(message.id)
      return
    }
    if (!accountId) return
    const pendingMessage = messages.find((message) => message.sendStatus && message.authorId === accountId && !scrolledPending.has(message.id))
    if (!pendingMessage) return
    scrolledPending.add(pendingMessage.id)
    await nextTick()
    if (channelId === props.channelId && channelId === store.channelId) jumpToLatest()
  }, { flush: 'post' })
  function updateHistoryAnchor(): void {
    const viewport = list.value
    if (!viewport) return
    const top = viewport.getBoundingClientRect().top, bottom = top + viewport.clientHeight
    const anchor = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find((item) => {
      const bounds = item.getBoundingClientRect(); return bounds.bottom > top && bounds.top < bottom
    })
    store.setHistoryAnchor(anchor?.dataset.messageId)
  }
  function onScroll(): void { const nearBottom = isHistoryNearBottom(list.value); historyWindow.syncScroll(nearBottom); updateHistoryAnchor(); if (nearBottom) jumpCount.value = 0; emit.viewportChange() }
  function jumpToLatest(): void { if (!list.value) return; list.value.scrollTop = list.value.scrollHeight; historyWindow.syncScroll(true); updateHistoryAnchor(); jumpCount.value = 0; emit.viewportChange() }
  async function openReplyContext(messageId: string): Promise<void> {
    if (historyWindow.scrollToMessage(messageId)) { await nextTick(); navigateToReplyTarget(list.value, messageId, () => emit.replyContext(messageId)); return }
    navigateToReplyTarget(list.value, messageId, () => emit.replyContext(messageId))
  }
  async function showMessage(messageId: string): Promise<boolean> {
    if (!historyWindow.scrollToMessage(messageId)) return false
    await nextTick()
    const shown = scrollToMessageTarget(list.value, messageId)
    if (shown) { historyWindow.syncScroll(); updateHistoryAnchor(); emit.viewportChange() }
    return shown
  }
  function beginTargetNavigation(): void { targetNavigationDepth++; historyWindow.syncScroll(false) }
  function endTargetNavigation(): void { targetNavigationDepth = Math.max(0, targetNavigationDepth - 1) }
  function replyPreview(message: TextMessage): string | undefined {
    if (!message.replyToId) return undefined
    const target = store.messageById.get(message.replyToId)
    if (!target) return 'Исходное сообщение недоступно'
    return target.deleted ? 'Сообщение удалено' : `${authors.displayName(target.authorId)}: ${target.body.slice(0, 140)}`
  }
  async function loadPage(load: () => Promise<boolean>): Promise<void> {
    const viewport = list.value, top = viewport?.getBoundingClientRect().top
    const focusedControl = viewport?.querySelector<HTMLButtonElement>('[data-history-control] button:focus'), scope = historyScope.value
    const restoreControl = () => {
      if (scope !== historyScope.value || !focusedControl || !viewport?.isConnected || document.activeElement !== document.body) return
      const bounds = viewport.getBoundingClientRect()
      const visible = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find((row) => {
        const rect = row.getBoundingClientRect(); return rect.bottom > bounds.top && rect.top < bounds.bottom
      })?.querySelector<HTMLElement>('.message-row')
      const target = focusedControl.isConnected ? focusedControl : visible ?? viewport.querySelector<HTMLElement>('[data-history-control] button:not(:disabled)')
      target?.focus({ preventScroll: true })
    }
    const anchor = [...(viewport?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])].find((item) => {
      const bounds = item.getBoundingClientRect(); return bounds.bottom > (top ?? 0) && bounds.top < (top ?? 0) + (viewport?.clientHeight ?? 0)
    })
    const anchorId = anchor?.dataset.messageId, anchorTop = anchor?.getBoundingClientRect().top
    const anchorOffset = anchorId ? historyWindow.offsetOf(anchorId) : undefined, channelId = props.channelId
    store.setHistoryAnchor(anchorId)
    if (!await load()) { await nextTick(); restoreControl(); return }
    const newOffset = anchorId ? historyWindow.offsetOf(anchorId) : undefined
    if (viewport && anchorOffset !== undefined && newOffset !== undefined) { viewport.scrollTop += newOffset - anchorOffset; historyWindow.syncScroll() }
    await nextTick()
    if (!viewport || channelId !== props.channelId) return
    if (anchorId && anchorTop !== undefined) {
      const current = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find((item) => item.dataset.messageId === anchorId)
      if (current) viewport.scrollTop += current.getBoundingClientRect().top - anchorTop
    }
    updateHistoryAnchor()
    restoreControl()
    emit.viewportChange()
  }
  const loadOlder = () => loadPage(() => store.loadOlder())
  const loadNewer = () => loadPage(() => store.loadNewer())
  return { store, timeline, announcement, jumpCount, historyWindow, historyScope, onScroll, jumpToLatest, openReplyContext, showMessage, beginTargetNavigation, endTargetNavigation, replyPreview, loadOlder, loadNewer }
}
