import { expect,test,type Page } from '@playwright/test'
const channel='11111111-1111-4111-8111-111111111111',message='22222222-2222-4222-8222-222222222222',author='33333333-3333-4333-8333-333333333333'
async function fixture(page:Page,admin=false){
 page.on('pageerror',error=>console.error('Component fixture error:',error.message))
 const commands:{method:string;url:string;body:string|null}[]=[];let present=false,pinned=true,reads=0
 await page.route('**/api/v1/members**',route=>route.fulfill({json:{members:[]}}))
 await page.route('**/message-reactions?**',route=>{reads++;return route.fulfill({json:{reactions:present?[{message_id:message,emoji:'👍',count:1,mine:true}]:[],can_pin:admin&&route.request().url().includes('/channels/')}})})
 await page.route('**/api/v1/**/messages/*/reactions/*',route=>{commands.push({method:route.request().method(),url:route.request().url(),body:route.request().postData()});present=route.request().method()==='PUT';return route.fulfill({status:204})})
 await page.route(`**/api/v1/channels/${channel}/pins`,route=>route.fulfill({json:{can_manage:admin,pins:pinned?[{message_id:message,pinned_at:'2026-10-09T12:01:00Z',author_id:author,preview:'<script>unsafe()</script>',message_created_at:'2026-10-09T12:00:00Z'}]:[]}}))
 await page.route(`**/api/v1/admin/text-channels/${channel}/pins/${message}`,route=>{commands.push({method:route.request().method(),url:route.request().url(),body:route.request().postData()});pinned=route.request().method()==='PUT';return route.fulfill({status:204})})
 await page.goto('/tests/message_social/fixture.html')
 return {commands,get reads(){return reads}}
}
test('real message has six desired-state reactions and recovery refresh; logout releases observers',async({page})=>{
 const state=await fixture(page)
 await page.locator('.reaction-picker summary').click()
 const like=page.locator('.reaction-palette').getByRole('button',{name:'Реакция 👍',exact:true})
 await expect(like).toBeEnabled();await expect(page.locator('.reaction-palette').getByRole('button')).toHaveCount(6)
 await like.click();await expect(like).toHaveAttribute('aria-pressed','true');await expect(like).toContainText('1')
 await like.click();await expect(like).toHaveAttribute('aria-pressed','false')
 expect(state.commands.map(c=>c.method)).toEqual(['PUT','DELETE']);expect(state.commands.every(c=>c.body===null)).toBeTruthy()
 const before=state.reads;await page.getByRole('button',{name:'Переподключиться'}).click();await expect.poll(()=>state.reads).toBeGreaterThan(before)
 await page.getByRole('button',{name:'Завершить сессию'}).click();const stopped=state.reads
 await page.getByRole('button',{name:'Переподключиться'}).click();await expect(page.getByRole('group',{name:'Реакции на сообщение'})).toHaveCount(0);expect(state.reads).toBe(stopped)
})
test('DM reaction uses private route and never exposes TEXT pin controls',async({page})=>{
 const state=await fixture(page,true);await page.getByRole('button',{name:'Открыть DM'}).click()
 await page.locator('.reaction-picker summary').click()
 const like=page.locator('.reaction-palette').getByRole('button',{name:'Реакция 👍',exact:true});await expect(like).toBeEnabled();await like.click();await expect(like).toHaveAttribute('aria-pressed','true')
 expect(state.commands[0].url).toContain(`/direct-messages/${channel}/messages/${message}/reactions/`)
 await expect(page.getByRole('button',{name:'Закрепить сообщение'})).toHaveCount(0)
 await page.getByRole('button',{name:'Открыть поиск'}).click();await expect(page.getByRole('button',{name:'Закреплённые',exact:true})).toHaveCount(0)
})
test('TEXT admin pin panel escapes preview, removes pin and opens original ID',async({page})=>{
 const state=await fixture(page,true);await page.locator('.reaction-picker summary').click();await page.getByRole('button',{name:'Закрепить сообщение'}).click();expect(state.commands[0].method).toBe('PUT')
 await page.getByRole('button',{name:'Открыть поиск'}).click();await page.getByRole('button',{name:'Закреплённые',exact:true}).click()
 await expect(page.getByText('<script>unsafe()</script>',{exact:true})).toBeVisible();await expect(page.locator('.pin-panel script')).toHaveCount(0)
 await page.getByRole('button',{name:'Снять закрепление'}).click();await expect(page.getByText('Закреплений пока нет.')).toBeVisible();expect(state.commands.at(-1)?.method).toBe('DELETE')
 await page.getByRole('button',{name:'Закрыть поиск'}).click();await page.getByRole('button',{name:'Закрепить сообщение'}).click()
 await page.getByRole('button',{name:'Открыть поиск'}).click();await page.getByRole('button',{name:'Закреплённые',exact:true}).click()
 await page.getByRole('button',{name:/Открыть закреплённое сообщение/}).click();await expect(page.getByTestId('target')).toHaveText(`CHANNEL:${channel}:${message}`)
})
test('failed metadata clears stale count and provides authoritative retry',async({page})=>{
 await fixture(page);await page.route('**/message-reactions?**',route=>route.fulfill({status:403}))
 await page.getByRole('button',{name:'Переподключиться'}).click();await expect(page.getByRole('alert')).toContainText('403')
 await page.locator('.reaction-picker summary').click()
 await expect(page.locator('.reaction-palette').getByRole('button',{name:'Реакция 👍',exact:true})).toBeDisabled();await expect(page.getByRole('button',{name:'Обновить реакции'})).toBeEnabled()
})
