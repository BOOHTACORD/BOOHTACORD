import {api,status,channel,expect,origin,openNavigation} from '../client_lifecycle/request.mjs'
import {login} from '../realtime_recovery/login.mjs'
import {observe} from './observe.mjs'

export async function client(browser,input,touch=false) {
  const context=await browser.newContext({ignoreHTTPSErrors:true,permissions:['microphone'],
    viewport:touch?{width:390,height:844}:{width:1440,height:960},hasTouch:touch,isMobile:touch})
  const page=await context.newPage();page.setDefaultTimeout(20000)
  await page.addInitScript(observe)
  return page
}

export async function setup(browser,input) {
  const sender=await client(browser,input), receiver=await client(browser,input)
  await login(sender,'qa_admin',input.password)
  await receiver.goto(origin)
  status(await api(receiver,'/auth/register','POST',{login:'qa_ptt_receiver',password:input.password}),201)
  await login(receiver,'qa_ptt_receiver',input.password)
  const category=await api(sender,'/admin/categories','POST',{name:'PTT Acceptance'});status(category,201)
  const voice=await api(sender,`/admin/categories/${category.body.id}/channels`,'POST',{name:'PTT Voice',kind:'VOICE'});status(voice,201)
  const text=await api(sender,`/admin/categories/${category.body.id}/channels`,'POST',{name:'PTT Text',kind:'TEXT'});status(text,201)
  for(const page of [sender,receiver])await join(page,voice.body.id)
  await configure(sender,false)
  await sender.screenshot({path:input.directory+'/assigned.png'})
  await closeSettings(sender)
  return {sender,receiver,room:voice.body.id,text:text.body.id}
}

export async function join(page,room) {
  await channel(page,'PTT Voice',room)
  await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
  await healthy(page)
}
export async function healthy(page) {
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён',{timeout:60000})
}
export async function configure(page,touch) {
  await openNavigation(page)
  await page.getByRole('button',{name:'Настройки аудио',exact:true}).click()
  await page.getByRole('combobox',{name:'Режим шумоподавления',exact:true}).selectOption('off')
  for(const name of ['Автоматическая громкость','Подавление эха']){
    const control=page.getByRole('switch',{name:new RegExp(name)})
    if(await control.isChecked())await control.click()
  }
  await page.getByRole('button',{name:'По нажатию',exact:true}).click()
  if(!touch){await page.getByRole('button',{name:'Назначить PTT-клавишу',exact:true}).click();await page.keyboard.press('v')}
}
export async function closeSettings(page) {
  await page.getByRole('button',{name:'Закрыть настройки аудио',exact:true}).click()
}
export async function bodyFocus(page) {
  await page.locator('body').click({position:{x:1100,y:800}})
}
export async function mediaControl(input,path) {
  const response=await fetch(input.control.base+path,{method:'POST',headers:{authorization:'Bearer '+input.control.token},signal:AbortSignal.timeout(15000)})
  if(response.status!==204)throw Error('Owned media action rejected')
}
