import { expect, test, type Page } from '@playwright/test'
import { routes } from '../microcopy/routes'
import { expectAxeClear } from '../accessibility/axe'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { createResponseGate } from './response_gate'

const scenes = [
  ...['guild', 'members', 'roles', 'channels', 'audit', 'media', 'readiness'].map(section => `admin&section=${section}`),
  'profile', ...['Безопасность', 'Уведомления', 'О приложении'].map(tab => `profile&tab=${tab}`), 'audio', 'audio&advanced=1',
]
async function open(page: Page, scene: string, scale = 100) {
  await routes(page)
  await page.goto(`/tests/settings_hierarchy/fixture.html?surface=${scene}&scale=${scale}`)
  const params = new URLSearchParams(`surface=${scene}`)
  if (params.get('tab')) await page.getByRole('tab', { name: params.get('tab')!, exact: true }).click()
  if (scene.includes('section=guild')) await expect(page.getByLabel('Название гильдии', { exact: true })).toBeEnabled()
  if (scene.includes('section=roles')) await expect(page.getByRole('tab', { name: 'Пользователь', exact: true })).toBeVisible()
  if (params.has('advanced')) await page.getByText('Дополнительно', { exact: true }).click()
  await page.evaluate(() => document.fonts.ready)
}
async function fit(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  for (const row of await page.locator('label:visible, button:visible, summary:visible').evaluateAll(es => es.filter(e=>!e.closest('nav') && e.checkVisibility({opacityProperty:true})).map(e => {
    const r=e.getBoundingClientRect();return { text:e.textContent?.trim().slice(0,60), left:r.left, right:r.right, width:innerWidth, clipped:e.tagName==='BUTTON' && e.scrollWidth>e.clientWidth+2 }
  }))) { expect(row.left).toBeGreaterThanOrEqual(-1); expect(row.right).toBeLessThanOrEqual(row.width+1); expect(row.clipped,JSON.stringify(row)).toBe(false) }
}
// Give each viewport/scene pair its own context and existing test deadline.
for (const width of [390, 1024, 1440]) for (const scene of scenes) test(`settings inventory and hierarchy ${width}px ${scene}`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  await open(page, scene)
  await fit(page)
  await page.screenshot({ path: info.outputPath(`${scene.replaceAll(/[&=]/g, '-')}.png`), fullPage: true })
  await expectAxeClear(page, 'main')
})
for (const width of [390,1024,1440]) for (const scale of [100,200]) test(`basic and advanced audio preserve values and expose warnings ${width}/${scale}`, async ({page},info)=>{
  await page.setViewportSize({width,height:900});await open(page,'audio',scale)
  const advanced=page.locator('.audio-advanced')
  await expect(advanced).not.toHaveAttribute('open','')
  await expect(page.getByRole('combobox',{name:/^Микрофон/})).toBeVisible()
  await expect(page.getByRole('switch',{name:'Шумоподавление',exact:true})).not.toBeVisible()
  const refresh=page.getByRole('button',{name:'Обновить устройства',exact:true});await expect(refresh).toHaveCSS('opacity','1')
  await page.getByRole('button',{name:'По нажатию',exact:true}).click();await expect(page.getByRole('button',{name:'Назначить PTT-клавишу'})).toBeVisible()
  const summary=advanced.locator(':scope > summary');await summary.focus();await summary.press('Enter')
  const echo=page.getByRole('switch',{name:/Подавление эха/});await echo.uncheck()
  const gain=page.getByRole('slider',{name:/Громкость микрофона/});await gain.focus();await gain.press('Home');for(let i=0;i<145;i++)await gain.press('ArrowRight')
  const agc=page.getByRole('switch',{name:/Автоматическая громкость/});await agc.check();await expect(gain).toBeDisabled()
  await summary.click();await page.evaluate(()=> (window as any).settingsFixture.microphoneFailure())
  await expect(page.getByRole('alert').filter({hasText:'Не удалось сохранить настройки микрофона.'})).toBeVisible()
  await expect(page.getByText('Перегрузка: уменьшите громкость микрофона.',{exact:true})).toBeVisible()
  await summary.click();await expect(echo).not.toBeChecked();await expect(agc).toBeChecked();await agc.uncheck();await expect(gain).toHaveValue('145')
  await fit(page);await page.screenshot({path:info.outputPath('advanced-retained.png'),fullPage:true})
})
test('guild explicit save state, pending, cancellation and conflict never silently overwrite a draft',async({page})=>{
  await open(page,'admin&section=guild')
  const form=page.getByRole('form',{name:'Настройки гильдии'}),name=page.getByLabel('Название гильдии',{exact:true}),save=form.getByRole('button',{name:'Сохранить',exact:true})
  await expect(save).toBeDisabled();await name.fill('Черновик');await expect(form.getByRole('status')).toHaveText('Есть несохранённые изменения')
  await form.getByRole('button',{name:'Отменить',exact:true}).click();await expect(name).toHaveValue('Тестовая гильдия');await expect(save).toBeDisabled()
  const response = createResponseGate()
  await page.route('**/api/v1/admin/guild-settings',async route=>{
    if(route.request().method()==='GET')return route.fulfill({json:{name:'Чужая правка',revision:2,welcome_channel_id:null}})
    await response.hold();await route.fulfill({status:409,json:{error:{code:'CONFLICT'}}})
  })
  await name.fill('Мой черновик');await save.click();await expect(form.getByRole('status')).toHaveText('Сохраняем…');await expect(name).toBeDisabled();await response.releaseNext()
  await expect(form.getByRole('alert')).toContainText('другой администратор');await expect(name).toHaveValue('Мой черновик');await expect(save).toBeEnabled()
  await form.getByRole('button',{name:'Отменить',exact:true}).click();await expect(name).toHaveValue('Чужая правка');await expect(save).toBeDisabled()
})
for(const width of [390,1024,1440])test(`permission warning, dirty/reset/cancel and denied result remain visible ${width}`,async({page},info)=>{
  await page.setViewportSize({width,height:900});await open(page,'admin&section=roles')
  await expect(page.locator('.role-permission-notice')).toBeVisible()
  const create=page.getByLabel('Создавать текстовые каналы',{exact:true});await create.uncheck()
  await expect(page.locator('.role-policy-status')).toHaveText('Есть несохранённые изменения');await expect(page.locator('.role-policy-status')).toBeVisible()
  await page.getByRole('button',{name:'Отменить',exact:true}).click();await expect(create).toBeChecked()
  await page.getByRole('button',{name:'По умолчанию',exact:true}).click();await expect(page.getByText('Загружены значения по умолчанию. Нажмите «Сохранить».',{exact:true})).toBeVisible()
  await create.uncheck();await page.route('**/api/v1/admin/roles/**',r=>r.fulfill({status:403,json:{error:{code:'FORBIDDEN'}}}))
  await page.getByRole('button',{name:'Сохранить',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Нет доступа');await expect(create).not.toBeChecked();await expect(page.getByRole('button',{name:'Сохранить',exact:true})).toBeDisabled()
  await fit(page);await page.screenshot({path:info.outputPath('denied-draft.png'),fullPage:true})
})
for(const width of [780,1440])test(`native browser zoom 200% keeps settings reachable ${width}`,async({playwright},info)=>{
 await withBrowserZoom(playwright.chromium,width,2,async page=>{
  for(const scene of ['audio&advanced=1','admin&section=roles','profile&tab=Безопасность']){
   await open(page,scene);await fit(page);expect(await page.evaluate(()=>devicePixelRatio)).toBe(2)
   expect(await page.evaluate(()=>getComputedStyle(document.documentElement).fontSize)).toBe('16px')
   await captureZoomedPage(page,info.outputPath(`${scene.replaceAll(/[&=]/g,'-')}-zoom.png`))
  }
 })
})
test('microphone processing failure is visible while Advanced is closed',async({page})=>{
 await open(page,'audio&phase=processing-error')
 await expect(page.locator('.audio-advanced')).not.toHaveAttribute('open','')
 await expect(page.getByRole('alert')).toHaveText('Ошибка обработки микрофона. Отправка звука выключена.')
})
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
 await name.fill('Новое имя');await save.click();await expect(page.getByRole('status')).toHaveText('Сохраняем имя профиля…');await expect(name).toBeDisabled();await response.releaseNext()
 await expect(page.getByRole('alert')).toBeVisible();await expect(name).toHaveValue('Новое имя')
 fail=false;await save.click();await expect(name).toBeDisabled();await response.releaseNext();await expect(page.getByRole('status')).toHaveText('Имя профиля сохранено.');expect(writes).toBe(2)
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
test('advanced shortcuts, device help and diagnostic restrictions remain keyboard reachable',async({page})=>{
 await open(page,'audio');await page.getByText('О проверке устройств',{exact:true}).focus();await page.keyboard.press('Enter')
 await expect(page.locator('.audio-check-details')).toHaveAttribute('open','')
 const summary=page.locator('.audio-advanced > summary');await summary.click()
 const assign=page.getByRole('button',{name:'Назначить сочетание: микрофон',exact:true});await assign.click();await assign.press('Control+Shift+M')
 const value=await page.locator('.audio-shortcut-row').first().locator('small').innerText();expect(value).not.toBe('Не назначено')
 await summary.click();await summary.click();await expect(page.locator('.audio-shortcut-row').first().locator('small')).toHaveText(value)
 await page.getByText('Режим и диагностика обработки',{exact:true}).click()
 await page.getByRole('combobox',{name:/Режим шумоподавления/}).selectOption('off')
 await expect(page.getByRole('switch',{name:'Шумоподавление',exact:true})).toHaveAttribute('aria-checked','false')
 await page.getByRole('switch',{name:'Шумоподавление',exact:true}).click()
 await expect(page.getByRole('combobox',{name:/Режим шумоподавления/})).toHaveValue('browser')
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
