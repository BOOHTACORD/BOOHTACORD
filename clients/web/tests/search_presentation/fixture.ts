import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import SearchPanel from '../../src/search/SearchPanel.vue'
import QuickJumpPanel from '../../src/search/QuickJumpPanel.vue'
import ConversationFilesPanel from '../../src/conversation/files_panel/ConversationFilesPanel.vue'
import '../../src/style.css'
const channel = '22222222-2222-4222-8222-222222222222'
const name = 'ОченьДлинноеНазваниеБезПробелов'.repeat(4)
const params = new URLSearchParams(location.search)
const surface = params.get('surface') ?? 'search'
const kind = params.get('kind') === 'dm' ? 'DIRECT_MESSAGE' : 'CHANNEL'
const action = ref('')
const changed = (value: string) => { action.value = value }
createApp({ render: () => h('main', { class: 'gc-shell search-active' }, [h('nav'), h('section'),
  h('aside', { class: 'members search-aside is-open' }, [
    surface === 'files' ? h(ConversationFilesPanel, { kind, conversationId: channel, onClose: () => changed('close'), onOpenMessage: changed })
    : surface === 'quick' ? h(QuickJumpPanel, { channels: [{ id: channel, name, kind: 'TEXT' }], people: [{ id: 'peer', displayName: name }], status: '', hasMore: true, onSelect: entry => changed(entry.id), onNext: () => changed('next') })
    : h(SearchPanel, { currentConversation: { id: channel, kind: 'CHANNEL', label: name }, channelLabels: { [channel]: name }, directMessageLabels: {}, onOpen: message => changed(message.id) }),
  ]), h('output', { hidden: true, 'data-testid': 'action' }, action.value),
]) }).use(createPinia()).mount('#app')
