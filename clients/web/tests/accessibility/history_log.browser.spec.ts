import {expect,test} from '@playwright/test'
import {expectAxeClear} from './axe'

for(const kind of ['TEXT','DM'])for(const state of ['empty','messages','pagination']){
 test(`history log ${kind} ${state} keeps legal child roles and keyboard actions`,async({page})=>{
  await page.setViewportSize({width:390,height:844});await page.goto('/')
  await page.evaluate(async({kind,state})=>{
   const load=(path:string)=>import(path),{createApp,h}=await load('/node_modules/.vite/deps/vue.js'),{createPinia}=await load('/node_modules/.vite/deps/pinia.js')
   const {default:Component}=await load(kind==='TEXT'?'/src/conversation/TextHistoryList.vue':'/src/direct_message/DirectMessageHistoryList.vue')
   const {useMessageStore}=await load('/src/conversation/message_store.ts'),{useDirectMessageStore}=await load('/src/direct_message/direct_message_store.ts')
   const pinia=createPinia(),store=kind==='TEXT'?useMessageStore(pinia):useDirectMessageStore(pinia)
   store.$patch({channelId:'channel-test',directMessageId:'dm-test',historyLoaded:true,loading:false,loadingHistory:false,nextCursor:state==='pagination'?'test-cursor':null,
    messages:state==='empty'?[]:[{id:'message-test',channelId:'channel-test',directMessageId:'dm-test',authorId:'own-test',body:'Test fixture',createdAt:'2026-10-12T10:00:00Z',updatedAt:'2026-10-12T10:00:00Z',revision:1,deleted:false,kind:'NORMAL',mentionUserIds:[],attachments:[]}]})
   document.body.innerHTML='<main id="mount" style="height:100vh;display:flex;flex-direction:column"></main>'
   createApp({render:()=>h(Component,{channelId:'channel-test',directMessageId:'dm-test',session:{accountId:'own-test',role:'MEMBER'},otherParticipantId:'peer-test',otherParticipantDisplayName:'Test peer'})}).use(pinia).mount('#mount')
  },{kind,state})
  const log=page.getByRole('log');await expect(log).toHaveAttribute('aria-live','off');await expect(page.getByRole('status').first()).toHaveAttribute('aria-atomic','true')
  await expectAxeClear(page,'.message-history-wrap')
  if(state==='pagination'){const older=log.getByRole('button',{name:'Показать предыдущие сообщения',exact:true});await older.focus();await expect(older).toBeFocused()}
  if(state!=='empty'){await expect(log.getByRole('button',{name:'Действия с сообщением',exact:true})).toBeVisible()}
 })
}
