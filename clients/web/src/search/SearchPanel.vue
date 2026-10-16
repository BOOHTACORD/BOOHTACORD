<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import SystemWelcomeMessage from '../conversation/system_welcome/SystemWelcomeMessage.vue'
import SearchResultBody from './SearchResultBody.vue'
import SearchFilters from './filters/SearchFilters.vue'
import { useSearchSessions, type SearchSession } from './session/state'
import { useSearchFilters } from './filters/state'
import { searchDateRange, type SearchDateRange } from './filters/date_range'
import ArchivePanel from '../channel/readonly_archive/ArchivePanel.vue'
import PinPanel from '../conversation/pins/PinPanel.vue'
import { useSearchTargetStore } from './search_target_store'
import PersonalMentionsPanel from './PersonalMentionsPanel.vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { searchMessages, type SearchMessage } from './search_messages_client'
import type { MentionInboxItem } from './mentions_inbox_client'
import { MessageRequestError } from '../conversation/message_client'

interface SearchConversation { id: string; kind: 'CHANNEL' | 'DIRECT_MESSAGE'; label: string }
const props = defineProps<{ currentConversation: SearchConversation | null; channelLabels: Record<string, string>; directMessageLabels: Record<string, string> }>()
const emit = defineEmits<{ open: [message: SearchMessage]; openMention: [mention: MentionInboxItem]; close: [] }>()
const activeView = ref<'messages' | 'mentions' | 'archives' | 'pins'>('messages')
const searchTarget = useSearchTargetStore()
watch(()=>props.currentConversation,value=>{if(activeView.value==='pins'&&value?.kind!=='CHANNEL')activeView.value='messages'})
const filters = useSearchFilters()
const sessions = useSearchSessions()
const origin = computed(() => props.currentConversation ? `${props.currentConversation.kind}:${props.currentConversation.id}` : 'global')
const initialSession = sessions.restore(origin.value)
const query = ref(initialSession?.query ?? '')
const scope = ref<'all' | 'current'>(initialSession?.scope ?? 'all')
const submitted = ref(initialSession?.submitted ?? false)
const panelRoot = ref<HTMLElement | null>(null)
let scrollHost: HTMLElement | null = null
let restoringSession = false
let restoredScrollTop = initialSession?.scrollTop ?? 0
let restoreScrollPending = initialSession?.submitted ?? false
let tabSequence = 0
let switchingView = false
function restoreFilters(saved: SearchSession | null): void {
  filters.authorId = saved?.authorId ?? ''
  filters.attachment = saved?.attachment ?? 'any'
  filters.dateFrom = saved?.dateFrom ?? ''
  filters.dateTo = saved?.dateTo ?? ''
}
restoreFilters(initialSession)
const authors = useAuthorDirectory()
const messages = ref<SearchMessage[]>([])
const nextCursor = ref('')
const activeQuery = ref(initialSession?.activeQuery ?? '')
const activeDates = ref<SearchDateRange>({})
const loading = ref(false)
const searched = ref(false)
const error = ref('')
const queryInput = ref<HTMLInputElement | null>(null)
let requestSequence = 0
const canSubmit = computed(() => !loading.value && Boolean(query.value.trim()) && (scope.value === 'all' || Boolean(props.currentConversation)))

function reset(): void { restoreScrollPending = false; restoredScrollTop = 0; submitted.value = false; requestSequence++; messages.value = []; nextCursor.value = ''; activeQuery.value = ''; activeDates.value = {}; loading.value = false; searched.value = false; error.value = '' }
watch(scope, () => { if (!restoringSession) reset() }, { flush: 'sync' })
watch(() => [filters.authorId, filters.attachment, filters.dateFrom, filters.dateTo], () => { if (!restoringSession) reset() }, { flush: 'sync' })
watch(messages, (items) => { for (const item of items) void authors.ensure(item.authorId) })
function snapshot(): SearchSession {
  return { query: query.value, activeQuery: activeQuery.value, scope: scope.value, authorId: filters.authorId, attachment: filters.attachment, dateFrom: filters.dateFrom, dateTo: filters.dateTo, submitted: submitted.value, scrollTop: restoredScrollTop }
}
function saveSession(): void {
  if (restoringSession) return
  sessions.save(origin.value, snapshot())
}
function rememberScroll(): void {
  if (activeView.value === 'messages' && !switchingView && scrollHost) restoredScrollTop = scrollHost.scrollTop
  saveSession()
}
// Other views may be shorter than results and clamp the shared rail to zero.
// Preserve the message position before DOM replacement, without caching hits/ACL.
watch(activeView, async (next, previous) => {
  if (previous === 'messages' && scrollHost) restoredScrollTop = scrollHost.scrollTop
  const ticket = ++tabSequence
  switchingView = true
  await nextTick()
  if (ticket !== tabSequence) return
  if (scrollHost) scrollHost.scrollTop = next === 'messages' ? restoredScrollTop : 0
  switchingView = false
  saveSession()
}, { flush: 'pre' })
watch(() => [query.value, activeQuery.value, scope.value, filters.authorId, filters.attachment, filters.dateFrom, filters.dateTo, submitted.value], saveSession, { flush: 'sync' })
watch(origin, (next, previous) => {
  sessions.save(previous, snapshot())
  tabSequence++; switchingView = false
  const saved = sessions.restore(next)
  restoringSession = true
  reset()
  query.value = saved?.query ?? ''
  activeQuery.value = saved?.activeQuery ?? ''
  scope.value = saved?.scope ?? 'all'
  restoreFilters(saved)
  submitted.value = saved?.submitted ?? false
  restoredScrollTop = saved?.scrollTop ?? 0
  restoreScrollPending = saved?.submitted ?? false
  restoringSession = false
  if (submitted.value) void runSearch(undefined, saved?.activeQuery)
}, { flush: 'sync' })

async function runSearch(before?: string, restoredQuery?: string): Promise<void> {
  const searchQuery = before ? activeQuery.value : restoredQuery ?? query.value
  if (!searchQuery.trim() || loading.value && !before) return
  if (!validCodePointLength(searchQuery.trim(), 1, 256)) { error.value = 'Запрос должен содержать до 256 символов.'; return }
  const conversation = scope.value === 'current' ? props.currentConversation : null
  if (scope.value === 'current' && !conversation) { error.value = 'Выберите беседу или ищите по всем беседам.'; return }
  const sequence = ++requestSequence
  if (!before && !restoreScrollPending) restoredScrollTop = 0
  if (!before) { messages.value = []; nextCursor.value = ''; searched.value = false }
  activeQuery.value = searchQuery
  submitted.value = true
  loading.value = true
  error.value = ''
  try {
    const dates = before ? activeDates.value : searchDateRange(filters.dateFrom, filters.dateTo)
    const page = await searchMessages({ query: searchQuery, ...dates, ...(conversation?.kind === 'CHANNEL' ? { channelId: conversation.id } : {}), ...(conversation?.kind === 'DIRECT_MESSAGE' ? { directMessageId: conversation.id } : {}), ...(filters.authorId ? { authorId: filters.authorId } : {}), ...(filters.attachment !== 'any' ? { hasAttachment: filters.attachment === 'with' } : {}), before })
    if (sequence !== requestSequence) return
    messages.value = before ? [...messages.value, ...page.messages] : page.messages
    nextCursor.value = page.nextCursor ?? ''
    activeQuery.value = searchQuery
    activeDates.value = dates
    searched.value = true
    await nextTick()
    if (sequence === requestSequence && !before && scrollHost) scrollHost.scrollTop = restoredScrollTop
    if (sequence === requestSequence) restoreScrollPending = false
  } catch (reason) {
    if (sequence === requestSequence) {
      if (!before || reason instanceof MessageRequestError && [401, 403, 404].includes(reason.status)) { messages.value = []; nextCursor.value = ''; searched.value = false }
      error.value = reason instanceof Error ? reason.message : 'Не удалось выполнить поиск сообщений.'
    }
  } finally { if (sequence === requestSequence) loading.value = false }
}

function conversationLabel(message: SearchMessage): string {
  return message.kind === 'CHANNEL' ? props.channelLabels[message.channelId] ?? 'Текстовый канал' : props.directMessageLabels[message.directMessageId] ?? 'Личный диалог'
}
function formattedDate(value: string): string { return new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }).format(new Date(value)) }
onBeforeUnmount(() => {
  tabSequence++
  saveSession()
  scrollHost?.removeEventListener('scroll', rememberScroll)
  requestSequence++
})
onMounted(() => {
  scrollHost = panelRoot.value?.querySelector<HTMLElement>('#search-mode-content') ?? panelRoot.value
  scrollHost?.addEventListener('scroll', rememberScroll, { passive: true })
  void nextTick(() => queryInput.value?.focus())
  if (submitted.value) void runSearch(undefined, initialSession?.activeQuery)
})
</script>

<template>
  <section ref="panelRoot" class="search-panel" aria-labelledby="search-panel-title" data-testid="search-panel">
    <div class="search-panel-controls">
    <header class="search-panel-heading"><h1 id="search-panel-title">{{ activeView === 'messages' ? 'Поиск сообщений' : activeView === 'archives' ? 'Архив' : activeView==='pins'?'Закреплённые':'Упоминания' }}</h1><button v-action-hint class="search-close" type="button" aria-label="Закрыть поиск" @click="emit('close')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m18 6-12 12M6 6l12 12" /></svg></button></header>
    <div class="search-view-tabs" role="group" aria-label="Поиск и упоминания">
      <button id="search-messages-tab" type="button" :aria-pressed="activeView === 'messages'" aria-controls="search-mode-content" @click="activeView = 'messages'">Сообщения</button>
      <button id="search-mentions-tab" type="button" :aria-pressed="activeView === 'mentions'" aria-controls="search-mode-content" @click="activeView = 'mentions'">Упоминания</button>
      <button type="button" :aria-pressed="activeView === 'archives'" aria-controls="search-mode-content" @click="activeView = 'archives'">Архив</button>
      <button v-if="currentConversation?.kind==='CHANNEL'" type="button" :aria-pressed="activeView==='pins'" aria-controls="search-mode-content" @click="activeView='pins'">Закреплённые</button>
    </div>
    </div>
    <div id="search-mode-content">
    <PinPanel v-if="activeView==='pins'&&currentConversation?.kind==='CHANNEL'" embedded :channel-id="currentConversation.id" @open="searchTarget.open($event);emit('close')" />
    <ArchivePanel v-else-if="activeView === 'archives'" embedded />
    <div v-else-if="activeView === 'mentions'" id="search-mentions-view" role="region" aria-label="Упоминания">
      <PersonalMentionsPanel :channel-labels="channelLabels" :direct-message-labels="directMessageLabels" @open="emit('openMention', $event)" />
    </div>
    <div v-else id="search-messages-view" role="region" aria-label="Поиск сообщений">
    <form class="search-form" role="search" @submit.prevent="runSearch()">
      <label class="search-query-label"><span class="visually-hidden">Запрос</span><input ref="queryInput" v-model="query" type="search" autocomplete="off" placeholder="Поиск сообщений" :disabled="loading" :aria-describedby="error ? 'search-error search-query-help' : 'search-query-help'"></label>
      <p id="search-query-help" class="gc-sr-only">Введите запрос и нажмите Enter или «Найти».</p>
      <div class="search-form-meta"><label class="search-scope-label"><span class="visually-hidden">Область поиска</span><select v-model="scope" :disabled="loading"><option value="all">Везде</option><option v-if="currentConversation" value="current">{{ currentConversation.label }}</option></select></label></div>
      <SearchFilters v-model:author-id="filters.authorId" v-model:attachment="filters.attachment" v-model:date-from="filters.dateFrom" v-model:date-to="filters.dateTo" :disabled="loading" />
      <button class="search-submit" type="submit" :disabled="!canSubmit">{{ loading ? 'Ищем…' : 'Найти' }}</button>
    </form>
    <p v-if="error" id="search-error" class="search-error" role="alert">{{ error }}</p>
    <p class="search-status" :class="{ 'search-status--visible': loading || (!error && searched && !messages.length) }" role="status" aria-live="polite" :aria-busy="loading">{{ loading ? 'Ищем сообщения…' : searched ? (messages.length ? `Найдено: ${messages.length}` : 'Совпадений нет.') : '' }}</p>
    <span v-if="searched && messages.length" class="search-result-count" aria-hidden="true">Найдено: {{ messages.length }}</span>
    <ol v-if="messages.length" class="search-results" aria-label="Результаты поиска">
      <li v-for="message in messages" :key="`${message.kind}:${message.id}`" class="search-result result-row">
        <article><header class="result-meta"><span class="result-source" :title="conversationLabel(message)">{{ conversationLabel(message) }}</span><time :datetime="message.createdAt">{{ formattedDate(message.createdAt) }}</time></header><div class="search-result-author"><span class="search-result-avatar" :style="{ backgroundColor: avatarBackground(message.authorId), color: avatarForeground(message.authorId) }">{{ avatarInitials(authors.displayName(message.authorId)) }}</span><strong :title="authors.displayName(message.authorId)">{{ authors.displayName(message.authorId) }}</strong></div><SystemWelcomeMessage v-if="message.messageKind === 'SYSTEM_WELCOME'" :author-id="message.authorId" :body="message.body" /><SearchResultBody v-else :body="message.body" :query="activeQuery" /><button type="button" :aria-label="`Открыть сообщение от ${authors.displayName(message.authorId)}`" @click="emit('open', message)">Открыть сообщение</button></article>
      </li>
    </ol>
    <button v-if="nextCursor" class="search-more gc-button gc-button--secondary" type="button" :disabled="loading" @click="runSearch(nextCursor)">Показать ещё</button>
    </div>
    </div>
  </section>
</template>

<style scoped>
.search-panel-controls { flex-shrink: 0; display: flow-root; padding-bottom: 1px; background: var(--gc-sidebar); }
.search-view-tabs { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 8rem), 1fr)); gap: 8px; margin: 12px 20px; }
.search-view-tabs button { min-width: 0; white-space: normal; overflow-wrap: anywhere; background: transparent; border: 1px solid var(--gc-border, #363a46); border-radius: var(--gc-radius-sm); color: inherit; cursor: pointer; min-height: 44px; padding: 6px 8px; }
.search-view-tabs button[aria-pressed="true"] { background: var(--gc-surface-raised, #20232d); border-color: var(--gc-accent, #6974f5); }
.search-view-tabs button:focus-visible { outline: 2px solid var(--gc-accent, #6974f5); outline-offset: 2px; }
</style>
