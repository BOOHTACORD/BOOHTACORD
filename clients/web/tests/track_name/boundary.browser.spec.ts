import { expect, test } from '@playwright/test'
for (const width of [393,1440]) {
 test(`real SDK legacy target is an honest launch profile at ${width}px`,async({page})=>{
  await page.setViewportSize({width,height:900})
  await page.goto('/tests/track_name/fixture.html')
  await page.evaluate(()=> (window as any).qa327.protocolFixture('screenshare-1080p-60fps'))
  await page.locator('.stream-diagnostics > summary').click()
  await expect(page.locator('.screen-diagnostics-target')).toHaveText('Профиль из имени дорожки: 1080p · 60 FPS')
  await expect(page.getByText('Профиль при запуске · имя дорожки',{exact:true})).not.toBeVisible()
  await page.getByText('Диагностика',{exact:true}).click()
  await expect(page.locator('.screen-diagnostics-details dl').getByText('Профиль при запуске · имя дорожки',{exact:true})).toBeVisible()
  await expect(page.getByText('Нет данных от отправителя',{exact:true})).toHaveCount(0)
  const state=await page.evaluate(()=> (window as any).qa327.snapshot())
  expect(state).toMatchObject({descriptor_present:false,SDK_trackName_present:true,legacy_name_present:false,active_video_outputs:0,subscriptions:0})
  await page.evaluate(()=> (window as any).qa327.protocolFixture('invalid-profile'))
  await expect(page.getByText('Нет данных от источника',{exact:true})).toHaveCount(0)
  await expect(page.locator('.screen-diagnostics-details').getByText('Профиль не передан отправителем.')).toBeVisible()
 })
}
