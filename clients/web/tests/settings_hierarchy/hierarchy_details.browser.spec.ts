import { expect, test } from '@playwright/test'
import { open, fit } from './hierarchy_helpers'
import { createResponseGate } from './response_gate'

test('profile and password cancellation send no mutation; explicit name save exposes pending/error/result',async({page})=>{
 await open(page,'profile');const name=page.getByRole('textbox',{name:'Отображаемое имя',exact:true}),save=page.getByRole('button',{name:'Сохранить профиль',exact:true})
 let writes=0,fail=true
 const response=createResponseGate()
 await page.route('**/api/v1/me',async route=>{
  if(route.request().method()!=='PATCH')return route.fallback()
  writes++;await response.hold()
  await route.fulfill(fail?{status:403,json:{error:{code:'FORBIDDEN'}}}:{json:{account_id:'11111111-1111-4111-8111-111111111111',login:'fixture',display_name:'Новое имя',role:'ADMINISTRATOR',avatar_url:null}})
 })
 await name.fill('Черновик');await page.getByRole('button',{name:'Отменить',exact:true}).click();await expect(name).toHaveValue('Тестовый участник');expect(writes).toBe(0)
 await name.fill('Новое имя');await save.click();await expect(page.getByRole('status').filter({hasText:'Сохраняем имя профиля…'})).toHaveText('Сохраняем имя профиля…');await expect(name).toBeDisabled();await response.releaseNext()
 await expect(page.getByRole('alert')).toBeVisible();await expect(name).toHaveValue('Новое имя')
 fail=false;await save.click();await expect(name).toBeDisabled();await response.releaseNext();await expect(page.getByRole('status').filter({hasText:'Имя профиля сохранено.'})).toHaveText('Имя профиля сохранено.');expect(writes).toBe(2)
 await page.getByRole('tab',{name:'Безопасность',exact:true}).click();await page.getByLabel('Текущий пароль',{exact:true}).fill('SyntheticOldOnly')
 await page.getByLabel('Новый пароль',{exact:true}).fill('SyntheticNewOnly');await page.getByRole('button',{name:'Отменить',exact:true}).click()
 await expect(page.getByLabel('Текущий пароль',{exact:true})).toHaveValue('');await expect(page.getByLabel('Новый пароль',{exact:true})).toHaveValue('')
 await expect(page.getByText('Голосовое подключение завершится, а личные данные исчезнут с этого экрана.',{exact:true})).toBeVisible()
 await expect(page.getByText('Завершённый сеанс потеряет доступ к сообщениям и голосу.',{exact:true})).toBeVisible()
 expect(writes).toBe(2)
})
test('profile avatar removal stays inside the card at enlarged mobile text',async({page},info)=>{
 await page.route('**/profile-avatar-fixture.svg',route=>route.fulfill({status:200,contentType:'image/svg+xml',body:'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><circle cx="20" cy="20" r="20" fill="#423657"/></svg>'}))
 for(const width of [390,432]){
  await page.setViewportSize({width,height:900});await open(page,'profile&avatar=1',200)
  const panel=page.locator('.profile-panel'),remove=page.getByRole('button',{name:'Удалить',exact:true})
  await expect(remove).toBeVisible()
  const geometry=await page.evaluate(()=>{
   const panel=document.querySelector('.profile-panel')!.getBoundingClientRect(),avatar=document.querySelector('.profile-avatar-row > .profile-avatar')!.getBoundingClientRect(),copy=document.querySelector('.profile-avatar-copy')!.getBoundingClientRect(),button=document.querySelector('.profile-avatar-row > .profile-secondary-button')!.getBoundingClientRect()
   return {panelLeft:panel.left,panelRight:panel.right,avatarRight:avatar.right,copyLeft:copy.left,copyBottom:copy.bottom,buttonLeft:button.left,buttonTop:button.top,buttonRight:button.right,viewport:innerWidth,scrollWidth:document.documentElement.scrollWidth}
  })
  expect(geometry.buttonLeft,JSON.stringify(geometry)).toBeGreaterThanOrEqual(geometry.panelLeft)
  expect(geometry.buttonRight,JSON.stringify(geometry)).toBeLessThanOrEqual(geometry.panelRight+1)
  expect(geometry.copyLeft,JSON.stringify(geometry)).toBeGreaterThanOrEqual(geometry.avatarRight)
  expect(geometry.buttonLeft,JSON.stringify(geometry)).toBeGreaterThanOrEqual(geometry.copyLeft-1)
  expect(geometry.buttonTop,JSON.stringify(geometry)).toBeGreaterThanOrEqual(geometry.copyBottom)
  expect(geometry.scrollWidth,JSON.stringify(geometry)).toBeLessThanOrEqual(geometry.viewport)
  await page.screenshot({path:info.outputPath(`profile-avatar-removal-${width}.png`),fullPage:true})
 }
})
test('shortcuts stay visible while device help and diagnostics remain keyboard reachable',async({page})=>{
 await open(page,'audio');await page.getByText('О проверке устройств',{exact:true}).focus();await page.keyboard.press('Enter')
 await expect(page.locator('.audio-device-check .audio-check-details')).toHaveAttribute('open','')
 const assign=page.getByRole('button',{name:'Назначить сочетание: микрофон',exact:true});await assign.click();await assign.press('Control+Shift+M')
 const value=await page.locator('.audio-shortcut-row').first().locator('small').innerText();expect(value).not.toBe('Не назначено')
 await expect(page.locator('.audio-shortcut-row').first().locator('small')).toHaveText(value)
 const noise=page.getByRole('combobox',{name:'Режим шумоподавления',exact:true})
 await noise.selectOption('off');await expect(noise).toHaveValue('off')
 await noise.selectOption('browser');await expect(noise).toHaveValue('browser')
 await page.locator('.audio-advanced > summary').click()
 await expect(page.locator('.audio-processing-values')).toBeVisible()
 await page.getByRole('button',{name:'Сбросить быстрые клавиши',exact:true}).click();await expect(page.locator('.audio-shortcut-row').first().locator('small')).toHaveText('Не назначено')
})
test('readiness details retain numbers and local actions, while freshness and failure remain outside',async({page},info)=>{
 await page.clock.install();await open(page,'admin&section=readiness')
 const panel=page.locator('.admin-readiness');await expect(panel.getByRole('status')).toHaveText('Сервисы готовы')
 await page.getByText(/Запас и технические показатели ·/).click();await expect(page.locator('.readiness-capacity')).toContainText('9536.7 МиБ')
 await page.getByText('Локальные измерения браузера',{exact:true}).click()
 await page.getByRole('button',{name:'Начать локальный прогон',exact:true}).click();await page.getByRole('button',{name:'Завершить прогон',exact:true}).click()
 await fit(page);await page.screenshot({path:info.outputPath('readiness-details.png'),fullPage:true})
 await page.getByText(/Запас и технические показатели ·/).click();await page.getByText('Локальные измерения браузера',{exact:true}).click()
 await page.clock.fastForward(16000);await expect(panel.getByRole('status')).toHaveText('Нет свежего подтверждения готовности')
 await page.route('**/api/v1/admin/readiness',r=>r.fulfill({status:503,json:{error:{code:'UNAVAILABLE'}}}));await page.getByRole('button',{name:'Обновить проверку',exact:true}).click()
 await expect(panel.getByRole('alert')).toBeVisible();await expect(page.locator('.readiness-probe--stale')).toHaveCount(3)
})

test('touch PTT settings do not request a keyboard key and explain the hold control',async({page},info)=>{
  await page.setViewportSize({width:390,height:844});await open(page,'audio&touchPtt=1')
  await page.getByRole('button',{name:'По нажатию',exact:true}).click()
  await expect(page.getByRole('button',{name:'Назначить PTT-клавишу'})).toHaveCount(0)
  await expect(page.getByText('Удерживайте кнопку микрофона в панели голосового канала, чтобы говорить.',{exact:true})).toBeVisible()
  await expect(page.getByRole('alert')).toHaveCount(0)
  await page.screenshot({path:info.outputPath('touch-ptt-settings-390x844.png'),fullPage:true})
})
