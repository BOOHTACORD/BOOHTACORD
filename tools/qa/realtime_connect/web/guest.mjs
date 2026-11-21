import assert from 'node:assert/strict'
import { expect, origin } from '../../client_lifecycle/request.mjs'
import { control } from './observe.mjs'

export async function guestFaults(page,input) {
  await page.goto(origin)
  await expect.poll(() => page.evaluate(() => window.__r2.guest.ready)).toBe(true)
  const rows=[]
  for(const mode of ['public-upgrade-error','public-upgrade-stall','public-ready-stall','public-split-budget']) {
    await control(page,input.token,mode)
    const before=await page.evaluate(()=>window.__r2.guest.constructed), started=Date.now()
    await page.evaluate(()=>window.__r2.guest.socket.close())
    await expect.poll(async()=>(await control(page,input.token)).seen).toBe(1)
    if(mode==='public-upgrade-stall') await page.screenshot({path:input.directory+'/public-stalled.png'})
    await expect.poll(()=>page.evaluate(()=>window.__r2.guest.constructed),{timeout:15000}).toBeGreaterThan(before)
    await expect.poll(()=>page.evaluate(()=>window.__r2.guest.ready&&window.__r2.guest.socket.readyState===1),{timeout:15000}).toBe(true)
    const ms=Date.now()-started
    if(mode!=='public-upgrade-error') assert.ok(ms>=2500&&ms<10000,'Guest budget exceeded')
    const sample=await control(page,input.token)
    console.log('R2_PUBLIC',mode,JSON.stringify(sample),ms)
    if(mode!=='public-upgrade-error') assert.equal(sample.cancelled,true)
    rows.push({...sample,recovered_ms:ms})
  }
  await control(page,input.token,'public-upgrade-stall')
  await page.evaluate(()=>window.__r2.guest.socket.close())
  await expect.poll(async()=>(await control(page,input.token)).seen).toBe(1)
  await page.goto('about:blank')
  await expect.poll(async()=>{
    const response=await page.request.get(origin+'/qa-r2/control',{headers:{authorization:'Bearer '+input.token}})
    if(!response.ok())throw Error('Owned guest cancellation observation failed')
    return (await response.json()).cancelled
  },{timeout:5000}).toBe(true)
  await page.goto(origin)
  await expect.poll(()=>page.evaluate(()=>window.__r2.guest.ready&&window.__r2.guest.socket.readyState===1)).toBe(true)
  return rows
}
