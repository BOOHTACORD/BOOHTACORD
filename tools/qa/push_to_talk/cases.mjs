import assert from 'node:assert/strict'
import {expect,channel} from '../client_lifecycle/request.mjs'
import {audio,sample} from './observe.mjs'
import {bodyFocus,join,healthy,mediaControl} from './setup.mjs'

export async function desktop(h,input,report) {
  const {sender:a,receiver:b}=h,dock=a.getByTestId('voice-dock')
  await audio(a,b,false,report,'idle')
  await bodyFocus(a);await a.keyboard.down('v');await audio(a,b,true,report,'held')
  await a.screenshot({path:input.directory+'/held.png'})
  await a.keyboard.up('v');await audio(a,b,false,report,'released')
  await a.screenshot({path:input.directory+'/released.png'})
  await channel(a,'PTT Text',h.text)
  await a.locator('#message-body').focus();await a.keyboard.down('v')
  await audio(a,b,false,report,'editing');await a.keyboard.up('v')
  await channel(a,'PTT Voice',h.room);await bodyFocus(a)
  await a.keyboard.down('v');await audio(a,b,true,report,'before-deafen')
  await dock.getByRole('button',{name:'Выключить удалённый звук',exact:true}).click()
  await a.keyboard.up('v');await audio(a,b,false,report,'released-during-deafen')
  await dock.getByRole('button',{name:'Включить удалённый звук',exact:true}).click()
  await audio(a,b,false,report,'undeafened-no-key')
  await a.screenshot({path:input.directory+'/undeafened.png'})
  await dock.getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
  await join(a,h.room);await bodyFocus(a)
  await audio(a,b,false,report,'listener-rejoin-idle')
  await a.keyboard.down('v');await audio(a,b,true,report,'listener-rejoin-held')
  await a.keyboard.up('v');await audio(a,b,false,report,'listener-rejoin-release')
  await a.getByRole('button',{name:'Открыть настройки профиля',exact:true}).click()
  await a.getByRole('tab',{name:'Безопасность',exact:true}).click()
  await a.getByRole('button',{name:'Выйти из аккаунта',exact:true}).click()
  const modal=a.getByRole('dialog',{name:'Подтвердите выход из аккаунта'})
  await expect(modal).toBeVisible();await a.keyboard.down('v');await audio(a,b,false,report,'modal')
  await a.keyboard.up('v');await modal.getByRole('button',{name:'Отмена',exact:true}).click()
  await a.getByRole('button',{name:'Закрыть настройки',exact:true}).click()
  const cdp=await a.context().newCDPSession(a)
  await cdp.send('Emulation.setFocusEmulationEnabled',{enabled:false})
  await a.bringToFront();await bodyFocus(a)
  await expect.poll(()=>a.evaluate(()=>document.hasFocus())).toBe(true)
  await a.keyboard.down('v');await audio(a,b,true,report,'before-focus-loss')
  const {windowId}=await cdp.send('Browser.getWindowForTarget')
  await cdp.send('Browser.setWindowBounds',{windowId,bounds:{windowState:'minimized'}})
  await expect.poll(async()=>(await cdp.send('Runtime.evaluate',{
    expression:"document.hidden || !document.hasFocus()",returnByValue:true,
  })).result.value,{timeout:5000,message:'Actual owned browser focus loss required'}).toBe(true)
  await audio(a,b,false,report,'real-blur')
  await cdp.send('Browser.setWindowBounds',{windowId,bounds:{windowState:'normal'}})
  await a.bringToFront();await a.keyboard.down('v');await audio(a,b,false,report,'held-key-repeat-after-blur')
  await a.keyboard.up('v');await bodyFocus(a)
  await a.keyboard.down('v');await audio(a,b,true,report,'fresh-key-after-blur')
  await a.keyboard.up('v');await audio(a,b,false,report,'fresh-key-release')
}

export async function recovery(h,input,report) {
  const {sender:a,receiver:b}=h
  await bodyFocus(a);await a.keyboard.down('v');await audio(a,b,true,report,'before-outage-held')
  const before=await sample(a)
  await mediaControl(input,'/stop-sfu')
  await expect(a.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Восстанавливаем голосовое соединение',{timeout:25000})
  await a.waitForTimeout(30000)
  await mediaControl(input,'/start-sfu')
  await healthy(a);await healthy(b)
  await expect.poll(async()=>(await sample(a)).constructed,{timeout:60000}).toBeGreaterThan(before.constructed)
  await audio(a,b,false,report,'recovered-no-fresh-key')
  await a.keyboard.down('v');await audio(a,b,false,report,'recovered-held-repeat')
  await a.keyboard.up('v');await a.keyboard.down('v');await audio(a,b,true,report,'recovered-fresh-key')
  await a.keyboard.up('v');await audio(a,b,false,report,'recovered-released')
  await a.screenshot({path:input.directory+'/recovered.png'})
}
