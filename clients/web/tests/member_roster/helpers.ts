import { expect, type Page } from '@playwright/test'
import { miniRoutes } from '../mini_player/routes'
import { own, peer } from '../chat_rhythm/data'
export const fullName = 'Собеседник с очень длинным именем участника и дополнительной фамилией'
export const members = Array.from({length:30},(_,i)=>({user_id:i===0?peer:i===1?own:`qa-member-${i}`,login:`person${i}`,display_name:i===0?fullName:`Участник ${i}`,role:i===0?'ADMINISTRATOR':'MEMBER',presence:i<10?'online':i<20?'offline':'unknown'}))
export async function routes(page:Page) {
 await miniRoutes(page)
 await page.route('**/api/v1/members?*',r=>r.fulfill({json:{members}}))
 await page.route('**/api/v1/members/*',r=>r.fulfill({json:members.find(m=>r.request().url().endsWith(m.user_id))??members[0]}))
}
export async function mount(page:Page,width=1440,scale=100,height=900) {
 await page.setViewportSize({width,height});await routes(page)
 await page.goto(`/tests/member_roster/fixture.html?scale=${scale}`)
 await page.locator('[data-testid=stream-select]:visible').first().click()
 await expect(page.getByRole('button',{name:/закрепить просмотр|открепить просмотр/i})).toHaveCount(0)
 await page.evaluate(()=>(window as any).__membersFixture.navigate('text'))
 await expect(page.locator('.voice-room--mini')).toBeVisible()
 if(!(await page.getByTestId('members-panel').isVisible()))await page.getByRole('button',{name:'Открыть участников',exact:true}).click()
 await expect(page.locator('.members-guild-roster .member-card')).toHaveCount(30)
}
export async function openProfile(page:Page) {
 const trigger=page.getByRole('button',{name:`Профиль: ${fullName} · В сети`,exact:true})
 await trigger.focus();await page.keyboard.press('Enter')
 await expect(page.getByTestId('member-popover').getByRole('heading',{name:fullName,exact:true})).toBeVisible()
 return trigger
}
export async function geometry(page:Page) {
 await expect.poll(()=>page.getByTestId('member-popover').evaluate(panel=>{
 const r=panel.getBoundingClientRect(),overlap=(a:DOMRect,b:DOMRect)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top
 return {bounded:r.left>=0&&r.top>=0&&r.right<=innerWidth+1&&r.bottom<=innerHeight+1,
 clear:[...document.querySelectorAll('.conversation-header,.composer-wrap,.voice-room--mini,[data-testid=voice-dock]')].every(e=>{const b=e.getBoundingClientRect();return !b.width||!b.height||!overlap(r,b)}),
 overflow:document.documentElement.scrollWidth>innerWidth,scrollable:panel.scrollHeight>panel.clientHeight}
 }).then(({bounded,clear,overflow})=>({bounded,clear,overflow}))).toEqual({bounded:true,clear:true,overflow:false})
}
