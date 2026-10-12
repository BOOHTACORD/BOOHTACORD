import {expect,test} from '@playwright/test'
import {expectAxeClear} from './axe'

for (const [props,label] of [
 [{microphoneMuted:false},'В голосовом канале'],
 [{microphoneMuted:true},'Микрофон выключен'],
 [{microphoneMuted:false,microphoneUnavailable:true},'Микрофон недоступен'],
 [{microphoneMuted:false,deafened:true},'Звук и микрофон выключены'],
 [{microphoneMuted:false,speaking:true},'Говорит'],
] as const) {
 test(`participant status exposes named icon: ${label}`, async({page})=>{
  await page.goto('/')
  await page.evaluate(async props=>{
   const load=(path:string)=>import(path),{createApp,h}=await load('/node_modules/.vite/deps/vue.js')
   const {default:Status}=await load('/src/voice/VoiceParticipantStatus.vue')
   document.body.innerHTML='<main id="mount"></main>'
   createApp({render:()=>h(Status,{...props,compact:true})}).mount('#mount')
  },props)
  await expectAxeClear(page,'#mount')
  await expect(page.getByRole('img',{name:label,exact:true})).toBeVisible()
  expect(await page.locator('svg').first().evaluate(e=>Boolean(e.closest('[aria-hidden="true"]')))).toBe(true)
 })
}
