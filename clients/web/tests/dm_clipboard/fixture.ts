import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import DirectMessageConversation from '../../src/direct_message/DirectMessageConversation.vue'
import { useDirectMessageStore } from '../../src/direct_message/direct_message_store'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import '../../src/style.css'
const first = '11111111-1111-4111-8111-111111111111', second = '22222222-2222-4222-8222-222222222222'
const own = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', scope = ref(first), pinia = createPinia()
const store = useDirectMessageStore(pinia)
useAuthorDirectory(pinia).acceptOwnProfile({ account_id: own, login: 'fixture', display_name: 'QA', role: 'MEMBER' })
store.directMessages = [first, second].map((id, index) => ({ id, otherParticipantId: index ? 'peer-b' : 'peer-a',
  otherParticipantDisplayName: index ? 'Второй' : 'Первый', createdAt: '2026-11-26T00:00:00Z', unreadCount: 0, mentionCount: 0 }))
store.directMessageId = first; store.historyLoaded = true
function select(next: 'first' | 'second') {
  scope.value = next === 'first' ? first : second; store.directMessageId = scope.value; store.messages = []; store.historyLoaded = true
}
declare global { interface Window { dmClipboardFixture: { select: typeof select } } }
window.dmClipboardFixture = { select }
createApp({ render: () => h('main', { class: 'main', style: 'height:100dvh' }, [h(DirectMessageConversation, {
  accountId: own, active: true, directMessageId: scope.value, otherParticipantId: scope.value === first ? 'peer-a' : 'peer-b',
  otherParticipantDisplayName: scope.value === first ? 'Первый' : 'Второй', navOpen: false,
})]) }).use(pinia).mount('#app')
