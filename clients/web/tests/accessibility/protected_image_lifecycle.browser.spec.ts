import { expect, test, type Route } from '@playwright/test'
import { qaImage } from '../protected_image_viewer/image'

for (const kind of ['TEXT', 'DM']) {
  test(`${kind} cancels a loading old scope and cannot revive it with late bytes`, async ({ page }) => {
    let release!: () => void, held!: Route, begin!: () => void
    const started = new Promise<void>(resolve => { begin = resolve })
    const waiting = new Promise<void>(resolve => { release = resolve })
    await page.route('**/api/v1/**/attachments/**', async route => {
      if (route.request().resourceType() === 'fetch' && route.request().url().includes('/first/')) {
        held = route; begin(); await waiting
        await held.fulfill({ status: 404, body: '' }).catch(() => {})
      } else await route.fulfill({ contentType: 'image/png', body: qaImage() })
    })
    await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
    const opener = page.getByRole('button', { name: 'Открыть изображение' })
    await opener.click(); await started
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Загружаем изображение…')).toBeVisible()
    const cancelled = page.waitForEvent('requestfailed', request => request.resourceType() === 'fetch' && request.url().includes('/first/'))
    await page.evaluate(() => window.viewerFixture.changeScope())
    await expect(dialog).not.toBeVisible(); await cancelled
    await opener.click(); await expect(dialog.locator('img')).toBeVisible()
    release()
    await expect(dialog.getByText('Вложение удалено или недоступно.')).toHaveCount(0)
    await expect(dialog.getByRole('link', { name: 'Скачать' })).toHaveAttribute('href', /\/second\/attachments\//)
  })

  test(`${kind} ignores a previous queued close event after an immediate reopen`, async ({ page }) => {
    await page.route('**/api/v1/**/attachments/**', route => route.fulfill({ contentType: 'image/png', body: qaImage() }))
    await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
    const opener = page.getByRole('button', { name: 'Открыть изображение' })
    await opener.click(); await expect(page.getByRole('dialog').locator('img')).toBeVisible()
    await page.evaluate(() => {
      document.querySelector('dialog')!.close()
      document.querySelector<HTMLButtonElement>('.attachment-card__open')!.click()
    })
    await expect(page.getByRole('dialog').locator('img')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Закрыть просмотр изображения' })).toBeFocused()
    await page.keyboard.press('Escape'); await expect(opener).toBeFocused()
  })
}
