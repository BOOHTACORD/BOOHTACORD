import { expect, test } from '@playwright/test'
import { qaImage } from '../protected_image_viewer/image'

for (const kind of ['TEXT', 'DM']) for (const failure of [403, 404, 410, 500, 'decode'] as const) {
  test(`${kind} image ${failure} stays private and has the correct recovery action`, async ({ page }) => {
    let repaired = false
    await page.route('**/api/v1/**/attachments/**', route => {
      const status = repaired || failure === 'decode' ? 200 : failure
      return route.fulfill({ status, contentType: 'image/png',
        body: repaired ? qaImage() : Buffer.from('private response diagnostic must never be rendered') })
    })
    await page.goto(`/tests/protected_image_viewer/fixture.html?kind=${kind}`)
    const opener = page.getByRole('button', { name: 'Открыть изображение' })
    await opener.click()
    const dialog = page.getByRole('dialog')
    const unavailable = failure === 404 || failure === 410
    await expect(dialog.getByText(unavailable ? 'Вложение удалено или недоступно.' : 'Не удалось загрузить изображение.')).toBeVisible()
    await expect(dialog.getByRole('link', { name: 'Скачать' })).toHaveCount(0)
    await expect(dialog.locator('img')).toHaveCount(0)
    await expect(page.getByText('private response diagnostic must never be rendered')).toHaveCount(0)
    const retry = dialog.getByRole('button', { name: 'Повторить', exact: true })
    if (unavailable) await expect(retry).toHaveCount(0)
    else {
      repaired = true; await retry.click()
      await expect(dialog.locator('img')).toBeVisible()
      await expect(dialog.getByRole('link', { name: 'Скачать' })).toBeVisible()
    }
    await page.keyboard.press('Escape')
    await expect(dialog).not.toBeVisible(); await expect(opener).toBeFocused()
  })
}
