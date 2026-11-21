import {expect} from '../client_lifecycle/request.mjs'
import {login} from '../realtime_recovery/login.mjs'
import {client,configure,closeSettings,join} from './setup.mjs'
import {audio} from './observe.mjs'

export async function touch(browser,h,input,report) {
  await h.sender.getByTestId('voice-dock').getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
  await h.sender.context().close()
  const page=await client(browser,input,true)
  await login(page,'qa_admin',input.password);await join(page,h.room)
  await configure(page,true);await closeSettings(page)
  const button=page.getByTestId('voice-dock').getByTestId('touch-ptt-button')
  await expect(button).toBeEnabled();await button.scrollIntoViewIfNeeded()
  const box=await button.boundingBox()
  if(!box)throw Error('Touch PTT geometry missing')
  const point={x:box.x+box.width/2,y:box.y+box.height/2,id:1}
  const cdp=await page.context().newCDPSession(page)
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point]})
  await expect(button).toHaveAttribute('aria-pressed','true')
  await audio(page,h.receiver,true,report,'touch-held')
  await page.screenshot({path:input.directory+'/touch-held.png'})
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...point,y:point.y-130}]})
  await audio(page,h.receiver,true,report,'touch-pointer-capture')
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]})
  await expect(button).toHaveAttribute('aria-pressed','false')
  await audio(page,h.receiver,false,report,'touch-released')
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point]})
  await audio(page,h.receiver,true,report,'touch-before-cancel')
  await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]})
  await expect(button).toHaveAttribute('aria-pressed','false')
  await audio(page,h.receiver,false,report,'touch-cancelled')
  await page.screenshot({path:input.directory+'/touch-released.png'})
}
