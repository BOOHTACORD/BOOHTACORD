import { createApp, defineComponent, h, nextTick, onBeforeUnmount, ref } from 'vue'
import { createPinia } from 'pinia'
import TextHistoryList from '../../src/conversation/TextHistoryList.vue'
import MessageItem from '../../src/conversation/MessageItem.vue'
import { provideHistoryEditors } from '../../src/conversation/history_window/editing_state/context'
import { useMessageStore } from '../../src/conversation/message_store'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import { clearDraftMemory, draftKey, loadDraft } from '../../src/conversation/draft_memory'
import { clearAuthenticatedState } from '../../src/identity/clear_authenticated_state'
import { useSavedComposer } from '../../src/conversation/use_saved_composer'
import { capture as capturePosition } from '../../src/conversation/context_position/dom'
import { newestVisibleServerMessageId } from '../../src/conversation/read_visibility'
import { channelA, channelB, own, peer, uid } from './history_edit_data'
import '../../src/style.css'

const pinia = createPinia(), store = useMessageStore(pinia), authors = useAuthorDirectory(pinia)
for (const [id, name] of [[own, 'Автор'], [peer, 'Участник']])
  authors.acceptOwnProfile({ account_id: id!, login: id!, display_name: name!, role: 'MEMBER' })
const channel = ref(channelA), account = ref(own), composerVisible = ref(true), listVisible = ref(true)
const fullCapacity = new URLSearchParams(location.search).has('capacity')
let capacitySize = () => 0
const Capacity = defineComponent({ setup() {
  const registry = provideHistoryEditors(); capacitySize = () => registry.size
  for (let index = 0; index < 500; index++) {
    const binding = registry.bind(`capacity-${index}`, { save: async () => ({ kind: 'saved' }), refresh: async () => null })
    binding.editor.begin({ body: `Capacity draft ${index}`, revision: 1 }); binding.unbind()
  }
  onBeforeUnmount(registry.dispose)
  return () => h(MessageItem, { message: { id: uid(1999), authorId: own, channelId: channelA,
    clientMessageId: uid(3999), body: 'Capacity fixture', revision: 1, createdAt: '2026-10-31T00:00:00Z', deleted: false }, canEdit: true, canDelete: true })
} })
let composer: ReturnType<typeof useSavedComposer<{ id: string }, { id: string }>>
const SavedComposer = defineComponent({ setup() {
  composer = useSavedComposer(own, 'CHANNEL', () => channel.value)
  return () => h('textarea', { 'aria-label': 'Fixture composer', value: composer.draft.value,
    onInput: (event: Event) => { composer.draft.value = (event.target as HTMLTextAreaElement).value } })
} })
await store.open(channelA)
const style = document.createElement('style')
style.textContent = '.history-edit-fixture{height:100vh;padding:12px}.history-edit-fixture nav{display:flex;gap:4px;flex-wrap:wrap}.history-edit-fixture .message-history-wrap{height:650px;position:relative}.history-edit-fixture .messages{height:630px;overflow:auto;position:relative}.history-edit-fixture>textarea{height:50px}'
document.head.append(style)
createApp({ render: () => h('main', { class: 'history-edit-fixture' }, [
  h('nav', [
    h('button', { onClick: async () => { channel.value = channel.value === channelA ? channelB : channelA; await store.open(channel.value) } }, 'Switch channel'),
    h('button', { onClick: () => { account.value = account.value === own ? peer : own } }, 'Switch account'),
    h('button', { onClick: () => { store.channelId = null; store.messages = []; store.historyLoaded = false } }, 'Reset store'),
    h('button', { onClick: () => { store.messages = [] } }, 'Empty store'),
    h('button', { onClick: () => store.channelId === channel.value ? store.refresh() : store.open(channel.value) }, 'Reload history'),
    h('button', { onClick: clearDraftMemory }, 'Clear draft memory'),
    h('button', { onClick: () => clearAuthenticatedState(pinia) }, 'Clear authenticated state'),
    h('button', { onClick: async () => { listVisible.value = false; await nextTick(); listVisible.value = true } }, 'Remount same account'),
    h('button', { onClick: () => { composer.draft.value = 'Late callback'; composerVisible.value = false } }, 'Late composer callback'),
  ]),
  listVisible.value ? fullCapacity ? h(Capacity) : h(TextHistoryList, { channelId: channel.value, session: { accountId: account.value, role: 'MEMBER' } }) : null,
  composerVisible.value ? h(SavedComposer) : null,
]) }).use(pinia).mount('#app')
Object.assign(window, { historyEditFixture: {
  cache: () => store.messages.map(({ id }) => id),
  busy: () => store.olderLoading || store.newerLoading,
  capacitySize: () => capacitySize(),
  remembered: (id = channelA) => loadDraft(draftKey(own, 'CHANNEL', id)),
  observed: () => { const list = document.querySelector<HTMLElement>('.message-list')
    return { anchor: capturePosition(list), visibleRead: newestVisibleServerMessageId(list, store.messages) } },
} })
