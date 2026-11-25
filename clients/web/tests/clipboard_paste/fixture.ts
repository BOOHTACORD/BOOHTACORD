import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import TextConversation from '../../src/conversation/TextConversation.vue'
import { useTopologyStore } from '../../src/channel/topology_store'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import '../../src/style.css'

const first = '11111111-1111-4111-8111-111111111111', second = '22222222-2222-4222-8222-222222222222'
const own = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', scope = ref(first), pinia = createPinia()
useAuthorDirectory(pinia).acceptOwnProfile({ account_id: own, login: 'fixture', display_name: 'QA', role: 'MEMBER' })
useTopologyStore(pinia).topology = { revision: 1, categories: [{ id: 'category', name: 'QA', position: 0,
  channels: [first, second].map((id, position) => ({ id, name: position ? 'Другой' : 'Первый', kind: 'TEXT' as const, position, admissionClosed: false })) }] }
declare global { interface Window { clipboardFixture: { select: (next: 'first' | 'second') => void } } }
window.clipboardFixture = { select: next => { scope.value = next === 'first' ? first : second } }
createApp({ render: () => h('main', { class: 'main', style: 'height:100dvh' }, [
  h(TextConversation, { accountId: own, active: true, channelId: scope.value, channelName: scope.value === first ? 'Первый' : 'Другой', navOpen: false, membersOpen: false, showMembers: false }),
]) }).use(pinia).mount('#app')
