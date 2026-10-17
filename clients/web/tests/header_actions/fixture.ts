import { createApp, h, reactive, ref, nextTick } from 'vue'
import { createPinia } from 'pinia'
import WorkspaceMain from '../../src/workspace/WorkspaceMain.vue'
import WorkspaceSearchPanel from '../../src/workspace/search/WorkspaceSearchPanel.vue'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import { useTopologyStore } from '../../src/channel/topology_store'
import { useDirectMessageStore } from '../../src/direct_message/direct_message_store'
import { own, peer, channel, dm } from '../chat_rhythm/data'
import '../../src/style.css'
const params = new URLSearchParams(location.search)
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
const pinia = createPinia()
const text = { id:channel, name:'Общий чат — длинное название 日本語 👩🏽‍💻', description:'Обсуждение проекта и полезные ссылки — длинная тема канала', kind:'TEXT' as const, position:0, admissionClosed:false }
const voice = { ...text, id:'voice', kind:'VOICE' as const, name:'Голосовая комната — длинное название 日本語' }
const direct = { id:dm, otherParticipantId:peer, otherParticipantDisplayName:'Собеседник — длинное имя 日本語 👩🏽‍💻', createdAt:'2026-10-15T10:00:00Z', unreadCount:0, mentionCount:0 }
useAuthorDirectory(pinia).acceptOwnProfile({ account_id:own,login:'fixture',display_name:'Тестовый клиент',role:'MEMBER' })
useAuthorDirectory(pinia).acceptOwnProfile({ account_id:peer,login:'peer',display_name:'Собеседник',role:'MEMBER' })
useTopologyStore(pinia).topology = { revision:1,categories:[{id:'general',name:'Общее',position:0,channels:[text,voice]}] }
useDirectMessageStore(pinia).directMessages = [direct]
type Panel = 'none'|'audio'|'profile'|'admin'
function settingsPanel(value:string):Panel { return value==='audio'||value==='profile'||value==='admin'?value:'none' }
const view = ref(params.get('surface') ?? 'text'), panel = ref<Panel>(settingsPanel(view.value))
const nav = ref(false), members = ref(false), search = ref(false)
const events:string[]=[]
const connection:any = reactive({ active:{channelId:voice.id},state:'CONNECTED',screenState:'IDLE',screenProfile:null,screenError:null,
 screenDiagnostics:{audioTrack:'UNKNOWN',connectionQuality:'UNKNOWN',source:'UNKNOWN',measured:null},
 screenViewerCards:[],
 screenViewerEnded:false,screenViewerError:null,selectedScreenStreamId:null,selectedScreenAudioVolume:75,screenAudioMuted:false,
 microphoneMuted:false,microphonePermissionDenied:false,deafened:false,deafenChanging:false,selfSpeaking:false,error:null,disconnectNotice:null,transferRequired:false,voiceVolumeError:null,
 voiceVolumeParticipants:[{id:'peer',accountId:peer,name:'Собеседник',speaking:false,microphoneMuted:false,volume:100}],
 toggleMicrophone:()=>{},toggleDeafen:()=>{connection.deafened=!connection.deafened},
 selectScreenStream:()=>events.push('select'),
 clearScreenStream:()=>{events.push('clear');connection.selectedScreenStreamId=null},
 setScreenVolume:(value:number)=>{connection.selectedScreenAudioVolume=value},toggleScreenAudio:()=>{connection.screenAudioMuted=!connection.screenAudioMuted},
 retryScreenStream:()=>events.push('retry'),setParticipantVolume:()=>{},refreshScreenDiagnostics:()=>{},stopScreen:()=>{},
})
Object.assign(window,{ headerFixture:{ async navigate(value:string) { panel.value=settingsPanel(value);if(panel.value==='none')view.value=value;search.value=false;if(value==='dm')await useDirectMessageStore(pinia).open(dm);await nextTick() },connection,events } })
if(view.value==='dm')void useDirectMessageStore(pinia).open(dm)
createApp({render:()=>h('div',{class:'app-frame'},[h('div',{class:['gc-shell',view.value==='voice'?'voice-stage-wide':view.value==='text'?'':'no-aside']},[
 h('aside',{class:'sidebar'},[h('p','Тестовая гильдия')]),
 h('main',{class:'main'},[
 view.value==='search' ? h(WorkspaceSearchPanel,{onClose:()=>{view.value='text'}}) : h(WorkspaceMain,{
  accountId:own,activeVoiceChannel:voice,panel:panel.value,channel:view.value==='voice'?voice:text,directMessage:view.value==='dm'?direct:null,
  joinVoice:()=>events.push('join'),leaveVoice:()=>events.push('leave'),activationMode:'VAD',startScreen:()=>events.push('capture'),selectedScreenProfile:'P1080_30',
  navOpen:nav.value,membersOpen:members.value,showMembers:!search.value,selfDisplayName:'Тестовый клиент',voiceConnection:connection,searchExpanded:search.value,
  onToggleNav:()=>{nav.value=!nav.value},onToggleMembers:()=>{members.value=!members.value},onOpenSearch:()=>{search.value=!search.value},onClosePanel:()=>{panel.value='none'},
 },{audio:()=>h('p','Содержимое настроек аудио'),profile:()=>h('p','Содержимое профиля'),admin:()=>h('p','Содержимое управления')})
 ]),
 view.value==='text'&&panel.value==='none'?h('aside',{class:'members'},'Участники'):null,
])])}).use(pinia).mount('#app')
