import { test, expect, type Page } from '@playwright/test'
import { routes } from '../microcopy/routes'
import { expectAxeClear } from '../accessibility/axe'
import { withBrowserZoom, captureZoomedPage } from '../control_consistency/browser_zoom'
const surfaces=['text','dm','voice','audio','profile','admin','search']
async function open(page:Page,surface='text',scale=100) {
 await routes(page);await page.goto(`/tests/header_actions/fixture.html?surface=${surface}&scale=${scale}`);await page.evaluate(()=>document.fonts.ready)
}
function header(page:Page) { return page.locator('header').filter({has:page.locator('.workspace-header-actions, .search-close')}).filter({visible:true}).first() }
async function fit(page:Page) {
 const result=await header(page).evaluate(el=>{
  const r=el.getBoundingClientRect(), buttons=[...el.querySelectorAll('button')].filter(b=>b.getClientRects().length)
  return {left:r.left,right:r.right,width:innerWidth,buttons:buttons.map(b=>{const r=b.getBoundingClientRect();return {label:b.getAttribute('aria-label'),left:r.left,right:r.right,width:r.width,height:r.height}})}
 })
 expect(result.left).toBeGreaterThanOrEqual(-1);expect(result.right).toBeLessThanOrEqual(result.width+1)
 for(const b of result.buttons){expect(b.label).toBeTruthy();expect(b.left).toBeGreaterThanOrEqual(result.left);expect(b.right).toBeLessThanOrEqual(result.right+1);expect(b.width).toBeGreaterThanOrEqual(await page.evaluate(()=>innerWidth<1024?44:36));expect(b.height).toBeGreaterThanOrEqual(36)}
 result.buttons.sort((a,b)=>a.left-b.left)
 for(let i=1;i<result.buttons.length;i++)expect(result.buttons[i]!.left).toBeGreaterThanOrEqual(result.buttons[i-1]!.right-1)
}
for(const width of [320,390,768,1440])test(`compact header grammar and all primary actions ${width}`,async({page},info)=>{
 await page.setViewportSize({width,height:900})
 for(const surface of surfaces){await open(page,surface);await fit(page);await expectAxeClear(page);await header(page).screenshot({path:info.outputPath(`${surface}.png`)})}
})
for(const width of [320,768,1440])test(`200% text keeps header actions and long accessible object ${width}`,async({page},info)=>{
 await page.setViewportSize({width,height:1000})
 for(const surface of surfaces){await open(page,surface,200);await fit(page);await header(page).screenshot({path:info.outputPath(`${surface}-text200.png`)})}
})
test('keyboard hints, expanded state, overflow navigation and files close restore their own trigger',async({page},info)=>{
 await page.setViewportSize({width:390,height:900});await open(page)
 const h=header(page), nav=h.locator('.workspace-header-toggle--nav')
 await nav.focus();await expect(page.getByRole('tooltip')).toHaveText('Открыть навигацию');await nav.press('Enter')
 await expect(h.getByRole('button',{name:'Закрыть навигацию',exact:true})).toHaveAttribute('aria-expanded','true')
 await nav.press('Enter');const search=h.getByRole('button',{name:'Найти сообщение',exact:true})
 await search.focus();await expect(page.getByRole('tooltip')).toHaveText('Найти сообщение');await search.press('Enter');await expect(search).toHaveAttribute('aria-expanded','true')
 const controls=await search.getAttribute('aria-controls');expect(controls).toBeTruthy();await expect(page.locator(`[id="${controls}"]`)).toBeVisible()
 await page.getByRole('button',{name:'Закрыть поиск в канале',exact:true}).click();await expect(search).toBeFocused();await expect(search).toHaveAttribute('aria-expanded','false')
 const more=h.getByRole('button',{name:'Другие действия',exact:true});await more.focus();await more.press('ArrowDown')
 await expect(page.getByRole('menuitem',{name:'Найти сообщение',exact:true})).toBeFocused();await more.press('End')
 await expect(page.getByRole('menuitem',{name:'Показать участников',exact:true})).toBeFocused();await page.keyboard.press('Escape');await expect(more).toBeFocused()
 await more.press('Enter');await page.getByRole('menuitem',{name:'Файлы беседы',exact:true}).click()
 await page.getByRole('button',{name:'Закрыть файлы беседы',exact:true}).click();await expect(more).toBeFocused()
 await expect(page.locator('textarea')).toHaveValue('');await page.screenshot({path:info.outputPath('keyboard-return.png')})
})
test('VOICE search reflects external panel; all settings close return to the same object and voice lease',async({page})=>{
 await open(page,'voice');const h=header(page), search=h.getByRole('button',{name:'Найти сообщение',exact:true})
 await expect(search).toHaveAttribute('aria-expanded','false');await search.click();await expect(search).toHaveAttribute('aria-expanded','true')
 await expect(search).toHaveAttribute('aria-controls','search-aside-panel')
 for(const surface of ['audio','profile','admin']){
  await page.evaluate(s=>(window as any).headerFixture.navigate(s),surface)
  await header(page).getByRole('button',{name:/Закрыть (настройки|администрирование)/}).click()
  await expect(page.locator('.voice-room h2')).toContainText('Голосовая комната')
 }
 expect(await page.evaluate(()=>(window as any).headerFixture.events.filter((event:string)=>['join','leave','capture'].includes(event)))).toEqual([])
 expect(await page.evaluate(()=>(window as any).headerFixture.connection.state)).toBe('CONNECTED')
})
test('search navigation mode has the same accessible close action and returns to conversation',async({page})=>{
 await open(page,'search');await page.getByRole('button',{name:'Каналы и люди',exact:true}).click();await page.keyboard.press('Tab')
 const close=page.getByRole('button',{name:'Закрыть поиск',exact:true});await expect(close).toHaveCSS('border-top-width','0px');await expect(close).toHaveCSS('background-color','rgba(0, 0, 0, 0)');await close.focus();await expect(page.getByRole('tooltip')).toHaveText('Закрыть поиск')
 await close.press('Enter');await expect(page.locator('#conversation-title')).toContainText('Общий чат')
})
for(const width of [640,1440])test(`actual browser zoom 200% ${width}`,async({playwright},info)=>{
 await withBrowserZoom(playwright.chromium,width,2,async page=>{
  for(const surface of surfaces){await open(page,surface);await fit(page);expect(await page.evaluate(()=>devicePixelRatio)).toBe(2);expect(await page.evaluate(()=>getComputedStyle(document.documentElement).fontSize)).toBe('16px');await captureZoomedPage(page,info.outputPath(`${surface}-zoom.png`))}
 })
})
test('decorative channel and DM symbols stay inside their icon slots at 200% text',async({page})=>{
 await page.setViewportSize({width:1440,height:900})
 for(const surface of ['text','dm']){
  await open(page,surface,200)
  const slot=header(page).locator('.conversation-symbol'), icon=slot.locator('svg')
  await expect(icon).toBeVisible()
  const outer=(await slot.boundingBox())!,inner=(await icon.boundingBox())!
  expect(inner.width).toBeLessThanOrEqual(outer.width);expect(inner.height).toBeLessThanOrEqual(outer.height)
  expect(inner.x).toBeGreaterThanOrEqual(outer.x);expect(inner.y).toBeGreaterThanOrEqual(outer.y)
  expect(inner.x+inner.width).toBeLessThanOrEqual(outer.x+outer.width);expect(inner.y+inner.height).toBeLessThanOrEqual(outer.y+outer.height)
 }
})
