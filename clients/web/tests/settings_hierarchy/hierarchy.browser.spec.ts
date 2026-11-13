import { expect, test } from '@playwright/test'
import { open, fit } from './hierarchy_helpers'
import { expectAxeClear } from '../accessibility/axe'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { createResponseGate } from './response_gate'

const scenes = [
  ...['guild', 'members', 'roles', 'channels', 'audit', 'media', 'readiness'].map(section => `admin&section=${section}`),
  'profile', ...['Безопасность', 'Уведомления', 'О приложении'].map(tab => `profile&tab=${tab}`), 'audio', 'audio&advanced=1',
]
// Give each viewport/scene pair its own context and existing test deadline.
for (const width of [390, 1024, 1440]) for (const scene of scenes) test(`settings inventory and hierarchy ${width}px ${scene}`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  await open(page, scene)
  await fit(page)
  await page.screenshot({ path: info.outputPath(`${scene.replaceAll(/[&=]/g, '-')}.png`), fullPage: true })
  await expectAxeClear(page, 'main')
})
for (const width of [390,1024,1440]) for (const scale of [100,200]) test(`audio essentials stay visible and diagnostics preserve values ${width}/${scale}`, async ({page},info)=>{
  await page.setViewportSize({width,height:900});await open(page,'audio',scale)
  const advanced=page.locator('.audio-advanced')
  await expect(advanced).not.toHaveAttribute('open','')
  await expect(page.getByRole('combobox',{name:/^Микрофон/})).toBeVisible()
  await expect(page.locator('.audio-processing-values')).not.toBeVisible()
  const noise=page.getByRole('combobox',{name:'Режим шумоподавления',exact:true});await expect(noise).toBeVisible()
  await expect(page.getByRole('button',{name:/Назначить сочетание: микрофон/})).toBeVisible()
  const refresh=page.getByRole('button',{name:'Обновить устройства',exact:true});await expect(refresh).toHaveCSS('opacity','1')
  await page.getByRole('button',{name:'По нажатию',exact:true}).click();await expect(page.getByRole('button',{name:'Назначить PTT-клавишу'})).toBeVisible()
  const echo=page.getByRole('switch',{name:/Подавление эха/});await echo.uncheck()
  const gain=page.getByRole('slider',{name:/Громкость микрофона/});await gain.focus();await gain.press('Home');for(let i=0;i<145;i++)await gain.press('ArrowRight')
  const agc=page.getByRole('switch',{name:/Автоматическая громкость/});await agc.check();await expect(gain).toBeDisabled()
  await noise.selectOption('off');await expect(noise).toHaveValue('off')
  await noise.selectOption('browser');await expect(noise).toHaveValue('browser')
  await page.evaluate(()=> (window as any).settingsFixture.microphoneFailure())
  await expect(page.getByRole('alert').filter({hasText:'Не удалось сохранить настройки микрофона.'})).toBeVisible()
  await expect(page.getByText('Перегрузка: уменьшите громкость микрофона.',{exact:true})).toBeVisible()
  await expect(echo).not.toBeChecked();await expect(agc).toBeChecked();await agc.uncheck();await expect(gain).toHaveValue('145')
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
test('microphone processing failure remains visible while diagnostics are closed',async({page})=>{
 await open(page,'audio&phase=processing-error')
 await expect(page.locator('.audio-advanced')).not.toHaveAttribute('open','')
 await expect(page.getByRole('alert')).toHaveText('Обработка микрофона остановлена. Отправка звука выключена.')
})
