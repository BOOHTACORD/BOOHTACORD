import { expect, test } from '@playwright/test'
test('real prejoin notice/actions fit 1440 and 1024 px', async ({page}) => {
 for (const width of [1440,1024]) {
  await page.setViewportSize({width,height:900})
  for (const reason of ['KICK','CHANNEL_CLOSED','BANNED','SESSION_REVOKED','LOGOUT','TRANSFER','TRANSPORT','VOLUNTARY_LEAVE']) {
   await page.goto('/tests/voice_disconnect_notice/fixture.html?reason='+reason)
   const notice = page.getByTestId('voice-disconnect-notice')
   await expect(notice).toBeVisible()
   await expect(notice).toHaveAttribute('role','status')
   if (reason === 'VOLUNTARY_LEAVE') await expect(notice).not.toHaveClass(/state-error/)
   else await expect(notice).toHaveClass(/state-error/)
   await expect(page.getByText('technical error')).toHaveCount(0)
   const allowed = !['CHANNEL_CLOSED','BANNED','SESSION_REVOKED','LOGOUT'].includes(reason)
   const join = page.getByRole('button',{name:'Войти',exact:true})
   if (allowed) {
    await expect(join).toBeEnabled()
    await join.click()
    await expect(page.locator('body')).toHaveAttribute('data-join','["synthetic-channel"]')
    await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
    await expect(page.locator('body')).toHaveAttribute('data-join','["synthetic-channel",false,"listener"]')
   } else {
    await expect(join).toBeDisabled()
    await expect(page.getByRole('button',{name:'Без микрофона',exact:true})).toBeDisabled()
   }
   expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
   await page.screenshot({path:`../../.out/visual/voice-notice/web-${width}-${reason}.png`})
  }
 }
})
test('voluntary leave is announced without error styling at a narrow viewport', async ({page}) => {
 await page.setViewportSize({width:393,height:852})
 await page.goto('/tests/voice_disconnect_notice/fixture.html?reason=VOLUNTARY_LEAVE')
 const notice = page.getByTestId('voice-disconnect-notice')
 await expect(notice).toBeVisible()
 await expect(notice).toHaveText('Голосовое подключение завершено.')
 await expect(notice).not.toHaveClass(/state-error/)
 await expect(page.getByRole('button',{name:'Войти',exact:true})).toBeEnabled()
 await expect(page.getByRole('button',{name:'Без микрофона',exact:true})).toBeEnabled()
 await page.screenshot({path:'../../.out/visual/voice-notice/web-393-VOLUNTARY_LEAVE.png'})
})
