import { expect, test } from '@playwright/test'
import { qaImage } from '../protected_image_viewer/image'

for (const kind of ['TEXT', 'DM']) {
  for (const width of [1440, 393, 320]) {
    test(`${kind} protected viewer fits ${width}px and restores keyboard focus`, async ({ page }, info) => {
      await page.setViewportSize({ width, height: 800 })
      const requests: string[] = []
      await page.context().route('**/api/v1/**/attachments/**', route => {
        requests.push(new URL(route.request().url()).pathname)
        return route.fulfill({ contentType: 'image/png', body: qaImage() })
      })
      await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
      const opener = page.getByRole('button', { name: 'Открыть изображение' })
      await opener.focus(); await page.keyboard.press('Enter')
      const dialog = page.getByRole('dialog'), image = dialog.locator('img')
      await expect(image).toBeVisible()
      await expect.poll(() => image.evaluate(node => (node as HTMLImageElement).naturalWidth)).toBe(256)
      await expect(dialog.getByRole('button', { name: 'Закрыть просмотр изображения' })).toBeFocused()
      const download = dialog.getByRole('link', { name: 'Скачать' })
      await expect(download).toHaveAttribute('href', `/api/v1/${kind === 'DM' ? 'direct-messages' : 'channels'}/first/attachments/shared-attachment`)
      expect(requests.every(url => url.endsWith('/preview'))).toBe(true)
      const bounds = await image.boundingBox()
      expect(bounds!.x).toBeGreaterThanOrEqual(0); expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(width)
      expect(bounds!.y + bounds!.height).toBeLessThanOrEqual(800)
      await image.evaluate(node => (node as HTMLImageElement).decode())
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
      await page.screenshot({ path: info.outputPath(`${kind}-${width}-viewer.png`) })
      const saving = page.waitForEvent('download')
      await download.click()
      const saved = await saving
      expect(saved.suggestedFilename()).toBe('Защищённое изображение с длинным именем.png')
      expect(new URL(saved.url()).pathname).toBe(await download.getAttribute('href'))
      // The real-stack journey verifies downloaded bytes; browser downloads bypass routed preview fixtures.
      await page.keyboard.press('Escape')
      await expect(dialog).not.toBeVisible(); await expect(opener).toBeFocused()
    })
  }
  test(`${kind} keeps Tab and Shift+Tab inside the modal`, async ({ page }) => {
    await page.route('**/api/v1/**/attachments/**', route => route.fulfill({ contentType: 'image/png', body: qaImage() }))
    await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
    await page.getByRole('button', { name: 'Открыть изображение' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.locator('img')).toBeVisible()
    for (const key of ['Tab', 'Shift+Tab']) for (let i = 0; i < 5; i++) {
      await page.keyboard.press(key)
      expect(await dialog.evaluate(node => node.contains(document.activeElement))).toBe(true)
    }
  })
  test(`${kind} closes an open viewer when its protected scope changes`, async ({ page }) => {
    await page.route('**/api/v1/**/attachments/**', route => route.fulfill({ contentType: 'image/png', body: qaImage() }))
    await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
    await page.getByRole('button', { name: 'Открыть изображение' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.locator('img')).toBeVisible()
    await page.evaluate(() => window.viewerFixture.changeScope())
    await expect(dialog).not.toBeVisible()
    await page.getByRole('button', { name: 'Открыть изображение' }).click()
    await expect(dialog.getByRole('link', { name: 'Скачать' })).toHaveAttribute('href', new RegExp('/second/attachments/'))
  })
  test(`${kind} returns focus to its own non-focusing activation trigger`, async ({ page }) => {
    await page.route('**/api/v1/**/attachments/**', route => route.fulfill({ contentType: 'image/png', body: qaImage() }))
    await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
    await page.locator('#outside').focus()
    const opener = page.getByRole('button', { name: 'Открыть изображение' })
    await opener.evaluate(node => (node as HTMLButtonElement).click())
    await expect(page.getByRole('dialog').locator('img')).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(opener).toBeFocused()
  })
}
