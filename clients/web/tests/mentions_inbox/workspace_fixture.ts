import { createApp, h } from 'vue'
import { createPinia, setActivePinia } from 'pinia'
import WorkspaceSearchPanel from '../../src/workspace/search/WorkspaceSearchPanel.vue'
import { useTopologyStore } from '../../src/channel/topology_store'
import { useDirectMessageStore } from '../../src/direct_message/direct_message_store'
import '../../src/style.css'

const id = '33333333-3333-4333-8333-333333333333'
const pinia = createPinia()
setActivePinia(pinia)
useTopologyStore().topology = { revision: 1, categories: [{ id: 'category', name: 'Fixture', position: 0,
  channels: [{ id, name: 'Cached text', kind: 'TEXT', position: 0, admissionClosed: false }] }] }
useDirectMessageStore().directMessages = [{ id, otherParticipantId: '44444444-4444-4444-8444-444444444444',
  otherParticipantDisplayName: 'Автор', createdAt: '2026-10-12T12:00:00Z', unreadCount: 0, mentionCount: 0 }]
createApp({ render: () => h(WorkspaceSearchPanel, {
  onOpenChannel: () => { document.body.dataset.opened = 'CHANNEL' },
  onOpenDirectMessage: () => { document.body.dataset.opened = 'DIRECT_MESSAGE' },
}) }).use(pinia).mount('#app')
