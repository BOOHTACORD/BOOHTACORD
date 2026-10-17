import { expect, type Page } from '@playwright/test'
import { miniRoutes as routes } from './routes'
export const navigate=(page:Page,view:string)=>page.evaluate(view=>(window as any).__miniFixture.navigate(view),view)
export async function mount(page:Page,width=1440,height=900,scale=100) {
 await page.setViewportSize({width,height});await routes(page)
 await page.goto(`/tests/mini_player/fixture.html?scale=${scale}`)
 await page.locator('[data-testid=stream-select]:visible').first().click()
 await expect.poll(()=>page.locator('video.screen-player').evaluate((v:HTMLVideoElement)=>v.videoWidth)).toBe(640)
 await page.getByRole('button',{name:'Закрепить просмотр',exact:true}).click()
 await page.locator('video.screen-player').evaluate(v=>{(window as any).__originalVideo=v;(window as any).__originalStream=(v as HTMLVideoElement).srcObject})
}
export async function geometry(page:Page) {
 const data=await page.evaluate(()=>{
  const box=(s:string)=>document.querySelector(s)!.getBoundingClientRect()
  const mini=box('.voice-room--mini'),composer=box('.composer'),dock=box('[data-testid=voice-dock]')
  const overlap=(a:DOMRect,b:DOMRect)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top
  const members=document.querySelector('.members-panel')!.getBoundingClientRect()
  const header=document.querySelector('.text-conversation > .conversation-header, .direct-message-conversation > .conversation-header')!.getBoundingClientRect()
  return {rosterClear:members.width===0 || (!overlap(mini,members) && !overlap(header,members)),bounded:mini.left>=0&&mini.right<=innerWidth&&mini.top>=0&&mini.bottom<=innerHeight,
   composerClear:!overlap(mini,composer),dockClear:!overlap(mini,dock),pageOverflow:document.documentElement.scrollWidth>innerWidth,
   controls:[...document.querySelectorAll('.screen-mini-toolbar button')].map(b=>{const r=b.getBoundingClientRect();return {w:r.width,h:r.height,inMini:r.left>=mini.left&&r.right<=mini.right&&r.top>=mini.top&&r.bottom<=mini.bottom}}),
   sameVideo:document.querySelector('video.screen-player')===(window as any).__originalVideo,
   sameStream:(document.querySelector('video.screen-player') as HTMLVideoElement)?.srcObject===(window as any).__originalStream}
 });expect(data.rosterClear).toBe(true);expect(data.bounded).toBe(true);expect(data.composerClear).toBe(true);expect(data.dockClear).toBe(true);expect(data.pageOverflow).toBe(false)
 expect(data.sameVideo).toBe(true);expect(data.sameStream).toBe(true)
 for(const c of data.controls){expect(c.w).toBeGreaterThanOrEqual(44);expect(c.h).toBeGreaterThanOrEqual(44);expect(c.inMini).toBe(true)}
 return data
}
