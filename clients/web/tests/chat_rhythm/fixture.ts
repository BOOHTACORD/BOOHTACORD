import { createApp, h, ref, nextTick } from 'vue'
import { createPinia } from 'pinia'
import TextConversation from '../../src/conversation/TextConversation.vue'
import DirectMessageConversation from '../../src/direct_message/DirectMessageConversation.vue'
import { useTopologyStore } from '../../src/channel/topology_store'
import { useDirectMessageStore } from '../../src/direct_message/direct_message_store'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import { useMessageStore } from '../../src/conversation/message_store'
import { messages, uid, own,peer,channel,dm } from './data'
import '../../src/style.css'
const kind = new URLSearchParams(location.search).get('kind') ?? 'CHANNEL'
const pinia = createPinia(), topology = useTopologyStore(pinia), authors = useAuthorDirectory(pinia)
authors.acceptOwnProfile({ account_id: own,login:'fixture',display_name:'Алексей — автор',role:'MEMBER' })
authors.acceptOwnProfile({ account_id: peer,login:'peer',display_name:'Собеседник с длинным именем для проверки',role:'MEMBER' })
topology.topology = {revision:1,categories:[{id:'general',name:'Общее',position:0,channels:[{id:channel,name:'Общий чат',kind:'TEXT',position:0,admissionClosed:false,unreadCount:0,mentionCount:0}]}]}
useDirectMessageStore(pinia).directMessages = [{id:dm,otherParticipantId:peer,otherParticipantDisplayName:'Собеседник',createdAt:'2026-10-15T10:00:00Z',unreadCount:0,mentionCount:0}]
const conversationVisible = ref(true)
if (kind !== 'CHANNEL') void useDirectMessageStore(pinia).open(dm)
createApp({ render:() => h('div',{class:'app-frame'},[h('div',{class:['gc-shell',{'no-aside':kind!=='CHANNEL'}]},[
  h('aside',{class:'sidebar','aria-label':'Тестовая навигация'},[h('p','Тестовая гильдия')]),
  h('main',{class:'main'},[!conversationVisible.value?null:kind==='CHANNEL'?h(TextConversation,{accountId:own,active:true,channelId:channel,channelName:'Общий чат',navOpen:false,membersOpen:false,showMembers:true}):h(DirectMessageConversation,{accountId:own,active:true,directMessageId:dm,otherParticipantId:peer,otherParticipantDisplayName:'Собеседник',navOpen:false})]),
  kind==='CHANNEL'?h('aside',{class:'members','aria-label':'Тестовые участники'}):null,
])]) }).use(pinia).mount('#app')

// Test-only mutations exercise the unchanged live-list watchers with a large history.
const history = kind === 'CHANNEL' ? useMessageStore(pinia) : useDirectMessageStore(pinia)
Object.assign(window, { rhythmFixture: {
  async remount() { conversationVisible.value=false; await nextTick(); conversationVisible.value=true; await nextTick() },
  replaceHistory(count: number) {
    const items = Array.from({ length: count }, (_, i) => ({ ...messages[0]!,
      id: uid(2000+i), clientMessageId: uid(4000+i), body: `История ${i}`,
      createdAt: new Date(Date.UTC(2026, 9, 15, 0, i)).toISOString(),
      ...(kind === 'CHANNEL' ? {channelId:channel} : {directMessageId:dm}),
    }))
    history.messages = items.reverse() as typeof history.messages
  },
  append() {
    history.messages = [{ ...history.messages[0]!, id:uid(8000), clientMessageId:uid(8001),
      createdAt:'2026-10-17T10:00:00Z', body:'Новое сообщение', authorId:peer }, ...history.messages] as typeof history.messages
  },
} })
