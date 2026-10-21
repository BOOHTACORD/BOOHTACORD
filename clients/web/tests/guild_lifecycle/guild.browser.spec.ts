import { expect,test } from '@playwright/test'
test('real public name, admin conflict, welcome selector and enlarged layout',async({page})=>{
 let name='Гильдия',revision=1,conflict=true,writes=0
 await page.route('**/api/v1/guild-profile',route=>route.fulfill({json:{name,revision}}))
 await page.route('**/api/v1/admin/guild-settings',async route=>{
  if(route.request().method()==='PATCH'){
   writes++;if(conflict){conflict=false;revision=2;await route.fulfill({status:409});return}
   const body=route.request().postDataJSON();expect(body.expected_revision).toBe(2);expect(body.welcome_channel_id).toBeNull();name=body.name;revision++
  }
  await route.fulfill({json:{name,revision,welcome_channel_id:null}})
 })
 await page.goto('/tests/guild_lifecycle/fixture.html')
 await expect(page.getByLabel('Название гильдии',{exact:true})).toHaveValue('Гильдия')
 await expect(page.getByLabel('Приветствия новых участников').locator('option')).toHaveCount(2)
 await page.getByLabel('Название гильдии',{exact:true}).fill('Черновик')
 await page.getByRole('button',{name:'Сохранить',exact:true}).click()
 await expect(page.locator('.guild-settings').getByRole('alert')).toContainText('другой администратор')
 await expect(page.getByLabel('Название гильдии',{exact:true})).toHaveValue('Черновик');expect(writes).toBe(1)
 await page.getByRole('button',{name:'Сохранить',exact:true}).click()
 await expect(page).toHaveTitle('Черновик')
 name='Ж'.repeat(80);revision++
 await page.evaluate(revision=>(window as any).profileHint({event_id:'hint',kind:'guild.profile.updated',occurred_at:'2026-10-05T00:00:00Z',payload:{revision}}),revision)
 await expect(page.locator('.guild-profile-name')).toHaveAttribute('title',name)
 if(page.viewportSize()!.width>=1024) await page.evaluate(()=>document.body.style.zoom='1.5')
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true)
})
test('system welcome follows member rename without reply or edit actions',async({page})=>{
 await page.route('**/api/v1/**',route=>route.fulfill({json:{name:'Гильдия',revision:1,welcome_channel_id:null}}))
 await page.goto('/tests/guild_lifecycle/fixture.html')
 await page.evaluate(()=>(window as any).renameMember('Новое имя'))
 await expect(page.getByLabel('Системное приветствие')).toContainText('@Новое имя')
 await expect(page.getByRole('button',{name:'Ответить'})).toHaveCount(0)
 await expect(page.getByRole('button',{name:'Изменить'})).toHaveCount(0)
 await page.evaluate(()=>(window as any).deleteWelcome())
 await expect(page.getByLabel('Системное приветствие')).toContainText('удалено')
})
