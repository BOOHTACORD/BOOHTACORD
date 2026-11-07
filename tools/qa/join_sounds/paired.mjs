import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { wav, observeCues, syntheticScreen } from './audio.mjs'
const require=createRequire(path.resolve('clients/web/package.json')), {chromium,expect}=require('@playwright/test')
const defines=JSON.parse(fs.readFileSync(process.env.QA_DEFINES_FILE,'utf8').replace(/^\uFEFF/,'')), base=defines.QA_API_BASE
if(base!=='https://localhost:4810/api/v1')throw Error('Owned endpoint required')
const browser=await chromium.launch({headless:true,args:['--allow-loopback-in-peer-connection']})
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms))
try {
 const contexts=await Promise.all([0,1].map(()=>browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:1000}})))
 const [admin,peer]=contexts, origin='https://localhost:4810'
 async function request(context,endpoint,method='GET',data,headers={}) {
  const response=await context.request.fetch(base+endpoint,{method,headers:{origin,...headers},...(data===undefined?{}:{data})})
  if(!response.ok())throw Error(`QA HTTP ${method} ${endpoint.replace(/[0-9a-f-]{36}/g,'ID')} ${response.status()}`)
  return response.status()===204?null:response.json()
 }
 await request(admin,'/auth/login','POST',{login:'qa_admin',password:defines.QA_PASSWORD})
 const peerLogin='qa_sounds_'+Date.now()
 await request(peer,'/auth/register','POST',{login:peerLogin,password:defines.QA_PASSWORD})
 await request(peer,'/auth/login','POST',{login:peerLogin,password:defines.QA_PASSWORD})
 const profile=await request(peer,'/me'), fence={'X-Voice-Sound-Account':profile.account_id}
 const sound=await request(peer,'/me/join-sound','POST',wav(),{...fence,'content-type':'application/octet-stream'})
 await request(peer,'/me/join-sound','PATCH',{enabled:true},fence)
 const category=await request(admin,'/admin/categories','POST',{name:'SoundLab'+Date.now()})
 const room=await request(admin,`/admin/categories/${category.id}/channels`,'POST',{name:'SoundLab',kind:'VOICE'})
 const [listener,sender]=await Promise.all(contexts.map(c=>c.newPage()))
 for(const page of [listener,sender]) {
  await page.addInitScript(observeCues);await page.goto(origin,{waitUntil:'domcontentloaded'})
  await page.locator('.channel-button').filter({hasText:'SoundLab'}).click()
 }
 const dock=page=>page.getByTestId('voice-dock')
 async function join(page) {
  await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
  await expect(dock(page).locator('.voice-status')).toHaveText('Голос подключён',{timeout:25000})
 }
 const count=page=>page.evaluate(()=>window.__qaCues.length)
 await join(listener);expect(await count(listener)).toBe(0)
 const downloads=[]
 listener.on('response',r=>{if(r.url().includes('/voice/join-sounds/'))downloads.push(r.status())})
 await join(sender)
 await expect.poll(()=>count(listener),{timeout:10000}).toBe(1)
 expect(await listener.evaluate(()=>window.__qaCues[0])).toBe('audio/mpeg')
 expect(downloads).toEqual([200]);expect(await count(sender)).toBe(0)
 await sender.evaluate(syntheticScreen)
 async function start() {
  await dock(sender).getByRole('button',{name:'Начать демонстрацию экрана',exact:true}).click()
  const setup=sender.getByRole('dialog',{name:'Демонстрация экрана',exact:true})
  await setup.getByRole('radio',{name:'720p',exact:true}).check()
  await setup.getByRole('radio',{name:'30 FPS',exact:true}).check()
  await setup.getByRole('button',{name:'Начать трансляцию',exact:true}).click()
  await expect(dock(sender).getByRole('button',{name:'Остановить демонстрацию экрана',exact:true})).toBeEnabled()
 }
 await start();await expect.poll(()=>count(listener)).toBe(2)
 await wait(5200)
 await dock(sender).getByRole('button',{name:'Остановить демонстрацию экрана',exact:true}).click()
 await expect.poll(()=>count(listener)).toBe(3)
 await start();await expect.poll(()=>count(listener)).toBe(4)
 await dock(sender).getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
 await expect.poll(()=>count(listener)).toBe(5);await wait(2000);expect(await count(listener)).toBe(5)
 await dock(listener).getByRole('button',{name:'Выключить удалённый звук',exact:true}).click()
 await join(sender);await wait(2000);expect(await count(listener)).toBe(5)
 await dock(sender).getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
 await request(peer,'/me/join-sound','DELETE',undefined,fence)
 await dock(listener).getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
 console.log('PAIRED_SOUND_PASS custom=private-http publisher_start_stop=true leave_suppresses_stop=true self_baseline_quiet=true deafen=true')
 for(const context of contexts)await context.close()
} finally {await browser.close()}
