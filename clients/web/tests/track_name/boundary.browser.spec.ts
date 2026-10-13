import { expect, test } from '@playwright/test'
for (const width of [393,1440]) {
 test(`real SDK legacy target is an honest launch profile at ${width}px`,async({page})=>{
  await page.setViewportSize({width,height:900})
  await page.goto('/tests/track_name/fixture.html')
  await page.evaluate(()=> (window as any).qa327.protocolFixture('screenshare-1080p-60fps'))
  await page.locator('.stream-diagnostics > summary').click()
  await expect(page.getByText('1080p · 60 FPS',{exact:true})).toBeVisible()
  await expect(page.getByText('Профиль при запуске · имя дорожки',{exact:true})).toBeVisible()
  await expect(page.getByText('Нет данных от отправителя',{exact:true})).toHaveCount(3)
  const state=await page.evaluate(()=> (window as any).qa327.snapshot())
  expect(state).toMatchObject({descriptor_present:false,SDK_trackName_present:true,legacy_name_present:false,active_video_outputs:0,subscriptions:0})
  await page.evaluate(()=> (window as any).qa327.protocolFixture('invalid-profile'))
  await expect(page.getByText('Нет данных от источника',{exact:true})).toBeVisible()
 })
}
