import { test, expect } from '@playwright/test'
import { mount, geometry, navigate } from './helpers'
import { expectAxeClear } from '../accessibility/axe'
for(const width of [320,390,1024,1440])for(const scale of [100,200])test(`chat zoning ${width} text ${scale}`,async({page},info)=>{
 await mount(page,width,900,scale)
 for(const view of ['text','dm']){
  await navigate(page,view);await expect(page.locator('.voice-room--mini')).toBeVisible()
  await geometry(page);await page.locator('.composer textarea').fill('Контрольный черновик')
  await expectAxeClear(page,'.screen-viewer')
  await page.screenshot({path:info.outputPath(`${view}.png`)})
 }
})
test('short viewport controls, pause, expand, unpin and close preserve media identity',async({page},info)=>{
 await mount(page,390,500);await navigate(page,'text');await geometry(page)
 const mini=page.locator('.voice-room--mini')
 const pause=mini.getByRole('button',{name:'Приостановить видео',exact:true});await pause.focus();await pause.press('Enter')
 await expect(mini.getByRole('button',{name:'Продолжить видео',exact:true})).toHaveAttribute('aria-pressed','true')
 await expect.poll(()=>page.locator('video.screen-player').evaluate((v:HTMLVideoElement)=>v.paused)).toBe(true)
 await mini.getByRole('button',{name:'Выключить звук трансляции',exact:true}).click()
 await page.screenshot({path:info.outputPath('short-paused.png')})
 await mini.getByRole('button',{name:'Развернуть на всю область',exact:true}).click()
 await expect(page.locator('.voice-room--screen-expanded')).toBeVisible();await expect(page.locator('.voice-room--mini')).toHaveCount(0)
 await expect(page.getByRole('button',{name:'Продолжить видео',exact:true})).toBeVisible()
 await page.keyboard.press('Escape');await geometry(page)
 await expect(mini.getByRole('button',{name:'Развернуть на всю область',exact:true})).toBeFocused()
 await page.getByRole('button',{name:'Продолжить видео',exact:true}).click()
 await expect.poll(()=>page.locator('video.screen-player').evaluate((v:HTMLVideoElement)=>v.paused)).toBe(false)
 await navigate(page,'settings');await expect(mini).toBeVisible()
 await mini.getByRole('button',{name:'Открепить просмотр и вернуться в голос',exact:true}).click()
 await expect(mini).toHaveCount(0);await expect(page.getByRole('button',{name:'Закрепить просмотр',exact:true})).toBeVisible()
 expect(await page.locator('video.screen-player').evaluate(v=>v===(window as any).__originalVideo)).toBe(true)
 await page.getByRole('button',{name:'Закрепить просмотр',exact:true}).click();await navigate(page,'text')
 await page.getByRole('button',{name:'Остановить просмотр',exact:true}).click();await expect(mini).toHaveCount(0)
 expect(await page.evaluate(()=>(window as any).__miniFixture.events)).toEqual(['select','clear','clear'])
})

test('deafen prevents mini audio overrides, absent audio is explicit, source end and logout remove controls',async({page})=>{
 await mount(page);await navigate(page,'text')
 await page.evaluate(()=>{(window as any).__miniFixture.connection.deafened=true})
 await expect(page.getByRole('button',{name:'Включить звук трансляции',exact:true})).toBeDisabled()
 await page.evaluate(()=>{const c=(window as any).__miniFixture.connection;c.deafened=false;c.screenViewerCards[0].hasAudio=false})
 await expect(page.getByRole('button',{name:'Выключить звук трансляции',exact:true})).toBeDisabled()
 await page.evaluate(()=>{const c=(window as any).__miniFixture.connection;c.screenViewerEnded=true;c.screenViewerCards=[]})
 await expect(page.getByRole('button',{name:'Остановить просмотр',exact:true})).toBeEnabled()
 await expect(page.getByRole('button',{name:'Приостановить видео',exact:true})).toBeDisabled()
 await page.evaluate(()=>{(window as any).__miniFixture.connection.active=null})
 await expect(page.locator('.voice-room--mini, video.screen-player')).toHaveCount(0)
})

test('long member rail scrolls independently while the mini player and composer remain usable',async({page},info)=>{
 await mount(page);await navigate(page,'text')
 await page.evaluate(()=>{(window as any).__miniFixture.connection.voiceVolumeParticipants=Array.from({length:30},(_,i)=>({id:`member-${i}`,accountId:`fixture-${i}`,name:`Участник ${i+1}`,speaking:false,microphoneMuted:false,volume:100}))})
 const members=page.getByTestId('members-panel')
 expect(await members.evaluate(el=>el.scrollHeight>el.clientHeight)).toBe(true)
 await members.getByRole('button',{name:'Профиль: Участник 30 · В голосовом канале',exact:true}).focus()
 await expect(members.getByRole('button',{name:'Профиль: Участник 30 · В голосовом канале',exact:true})).toBeInViewport()
 await page.locator('.composer textarea').fill('Черновик при прокрутке участников');await geometry(page)
 await page.screenshot({path:info.outputPath('roster-scroll.png')})
})

test('selecting a different voice room closes the old pinned viewer and keeps the original voice session',async({page})=>{
 await mount(page);await navigate(page,'other-voice')
 await expect(page.locator('video.screen-player')).toHaveCount(0)
 await expect(page.locator('.voice-room--mini')).toHaveCount(0)
 await expect(page.getByRole('button',{name:'Без микрофона',exact:true})).toBeVisible()
 await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
 expect(await page.evaluate(()=>(window as any).__miniFixture.connection.active.channelId)).toBe('voice')
})
