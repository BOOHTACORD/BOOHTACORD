import { test, expect, chromium } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { miniRoutes as routes } from './routes'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { geometry, navigate } from './helpers'
for(const width of [640,780,2048,2880])test(`mini at actual 200% browser zoom ${width}`,async({},info)=>{
 await withBrowserZoom(chromium,width,2,async page=>{
  await routes(page);await page.goto('http://127.0.0.1:4961/tests/mini_player/fixture.html')
  const zoom=await page.evaluate(()=>({outerWidth,innerWidth,dpr:devicePixelRatio,root:getComputedStyle(document.documentElement).fontSize,css:getComputedStyle(document.body).zoom,pinch:visualViewport!.scale}))
  expect(zoom).toEqual({outerWidth:width,innerWidth:width/2,dpr:2,root:'16px',css:'1',pinch:1})
  await page.locator('[data-testid=participant-screen-preview]:visible').first().click()
  await page.locator('video.screen-player').evaluate(v=>{(window as any).__originalVideo=v;(window as any).__originalStream=(v as HTMLVideoElement).srcObject})
  await navigate(page,'text');await geometry(page)
  await page.locator('.composer textarea').fill('Черновик при масштабе 200%')
  expect((await captureZoomedPage(page,info.outputPath('mini-zoom.png'))).readUInt32BE(16)).toBe(width)
  await writeFile(info.outputPath('zoom.json'),JSON.stringify(zoom,null,2))
 })
})
test('touch controls need no hover and remain above a resized keyboard viewport',async({browser},info)=>{
 const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true})
 try{
  const page=await context.newPage();await routes(page);await page.goto('http://127.0.0.1:4961/tests/mini_player/fixture.html')
  await page.locator('[data-testid=participant-screen-preview]:visible').first().tap()
  await page.locator('video.screen-player').evaluate(v=>{(window as any).__originalVideo=v;(window as any).__originalStream=(v as HTMLVideoElement).srcObject})
  await navigate(page,'text');await page.setViewportSize({width:390,height:460});await geometry(page)
  await page.getByRole('button',{name:'Приостановить трансляцию',exact:true}).tap()
  await page.getByRole('button',{name:'Выключить звук трансляции',exact:true}).tap()
  await page.locator('.composer textarea').fill('Текст рядом с трансляцией')
  await page.screenshot({path:info.outputPath('touch-short.png')})
  await page.getByRole('button',{name:'Остановить просмотр',exact:true}).tap();await expect(page.locator('.voice-room--mini')).toHaveCount(0)
 }finally{await context.close()}
})
