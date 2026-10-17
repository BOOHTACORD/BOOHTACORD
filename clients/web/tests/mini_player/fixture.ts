import { createApp, h, reactive, ref, nextTick } from 'vue'
import { createPinia } from 'pinia'
import WorkspaceMain from '../../src/workspace/WorkspaceMain.vue'
import WorkspaceMembersPanel from '../../src/workspace/WorkspaceMembersPanel.vue'
import VoiceDock from '../../src/voice/VoiceDock.vue'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import { useTopologyStore } from '../../src/channel/topology_store'
import { useDirectMessageStore } from '../../src/direct_message/direct_message_store'
import { own, peer, channel, dm } from '../chat_rhythm/data'
import '../../src/style.css'
const params = new URLSearchParams(location.search)
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
const pinia = createPinia()
const text = { id:channel, name:'Общий чат', kind:'TEXT' as const, position:0, admissionClosed:false }
const voice = { ...text, id:'voice', kind:'VOICE' as const, name:'Голосовая комната' }
const direct = { id:dm, otherParticipantId:peer, otherParticipantDisplayName:'Собеседник', createdAt:'2026-10-15T10:00:00Z', unreadCount:0, mentionCount:0 }
useAuthorDirectory(pinia).acceptOwnProfile({ account_id:own,login:'fixture',display_name:'Тестовый клиент',role:'MEMBER' })
useAuthorDirectory(pinia).acceptOwnProfile({ account_id:peer,login:'peer',display_name:'Собеседник',role:'MEMBER' })
useTopologyStore(pinia).topology = { revision:1,categories:[{id:'general',name:'Общее',position:0,channels:[text,voice]}] }
useDirectMessageStore(pinia).directMessages = [direct]
const view = ref('voice'), panel = ref<'none'|'audio'>('none')
const media = new MediaStream(), canvas = document.createElement('canvas'); canvas.width=640;canvas.height=360
const context=canvas.getContext('2d')!; context.fillStyle='#163d62';context.fillRect(0,0,640,360); context.fillStyle='#eef';context.font='36px sans-serif';context.fillText('Тестовая демонстрация',45,180)
canvas.captureStream(1).getTracks().forEach(track=>media.addTrack(track))
const events:string[]=[]
const connection:any = reactive({ active:{channelId:voice.id},state:'CONNECTED',screenState:'IDLE',screenProfile:null,screenError:null,
 screenDiagnostics:{audioTrack:'UNKNOWN',connectionQuality:'UNKNOWN',source:'UNKNOWN',measured:null},
 screenViewerCards:[{id:'peer:screen',participantId:'peer',accountId:peer,participantName:'Собеседник с длинным именем',hasAudio:true,isLocal:false}],
 screenViewerEnded:false,screenViewerError:null,selectedScreenStreamId:null,selectedScreenAudioVolume:75,screenAudioMuted:false,
 microphoneMuted:false,microphonePermissionDenied:false,deafened:false,deafenChanging:false,selfSpeaking:false,error:null,disconnectNotice:null,transferRequired:false,voiceVolumeError:null,
 voiceVolumeParticipants:[{id:'peer',accountId:peer,name:'Собеседник',speaking:false,microphoneMuted:false,volume:100}],
 toggleMicrophone:()=>{},toggleDeafen:()=>{connection.deafened=!connection.deafened},
 selectScreenStream:(_id:string,video:HTMLVideoElement,audio:HTMLAudioElement)=>{events.push('select');connection.selectedScreenStreamId='peer:screen';video.srcObject=media;audio.srcObject=media;void video.play()},
 clearScreenStream:()=>{events.push('clear');connection.selectedScreenStreamId=null},
 setScreenVolume:(value:number)=>{connection.selectedScreenAudioVolume=value},toggleScreenAudio:()=>{connection.screenAudioMuted=!connection.screenAudioMuted},
 retryScreenStream:()=>events.push('retry'),setParticipantVolume:()=>{},refreshScreenDiagnostics:()=>{},stopScreen:()=>{},
})
Object.assign(window,{ __miniFixture:{ navigate:async(value:string)=>{panel.value=value==='settings'?'audio':'none';if(value!=='settings')view.value=value;if(value==='dm')void useDirectMessageStore(pinia).open(dm);await nextTick()},connection,events } })
createApp({render:()=>h('div',{class:'app-frame'},[h('div',{class:'gc-shell'},[
 h('aside',{class:'sidebar'},[h('p',{class:'fixture-guild'},'Тестовая гильдия'),h('div',{style:'flex:1'}),h(VoiceDock,{error:null,channel:voice,activeSession:true,state:'CONNECTED',activationMode:'VAD',deafened:false,deafenChanging:false,microphoneMuted:false,microphonePermissionDenied:false,screenShareState:'IDLE',connectionQuality:'GOOD',pingMs:40,participantCount:2})]),
 h('main',{class:'main'},[h(WorkspaceMain,{accountId:own,activeVoiceChannel:connection.active?voice:null,panel:panel.value,channel:view.value==='other-voice'?{...voice,id:'other-voice',name:'Другая голосовая комната'}:view.value==='voice'?voice:text,directMessage:view.value==='dm'?direct:null,joinVoice:()=>{},leaveVoice:()=>{},activationMode:'VAD',startScreen:()=>{},selectedScreenProfile:'P1080_30',navOpen:false,membersOpen:false,showMembers:true,selfDisplayName:'Тестовый клиент',voiceConnection:connection,onReturnVoice:()=>{view.value='voice';panel.value='none'}},{audio:()=>h('p','Настройки звука')})]),
 h(WorkspaceMembersPanel,{activeVoiceChannel:voice,selectedVoiceChannel:voice,participants:connection.voiceVolumeParticipants,presenceResolver:(_id:string,fallback:any)=>fallback,role:'MEMBER',selfMicrophoneMuted:false,selfMicrophoneUnavailable:false,selfName:'Тестовый клиент',open:false,modal:false}),
])])}).use(pinia).mount('#app')

if (innerWidth < 1024) document.querySelector('.fixture-guild')?.remove()
