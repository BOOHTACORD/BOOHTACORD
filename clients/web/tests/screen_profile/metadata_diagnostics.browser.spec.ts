import { expect, test } from '@playwright/test'
import { mkdirSync } from 'node:fs'
import { resolve } from 'node:path'

test('renders sender configuration provenance separately from unknown measurements', async ({ page }) => {
  await page.goto('/tests/screen_profile/metadata_diagnostics.fixture.html')
  await page.getByLabel('Статистика', { exact: true }).click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await panel.getByText('Технические данные', { exact: true }).click()
  await expect(panel).toBeVisible()
  await expect(panel).toContainText('Конфигурация передана отправителем')
  await expect(panel).toContainText('SDK отправителя · лимиты, не измеренный FPS')
  await expect(panel).toContainText('Возраст захвата неизвестен')
  await expect(panel.locator('div').filter({ has: page.locator('dt', { hasText: /^Декодирование$/ }) })).toContainText('Нет данных')
  await page.evaluate(() => (window as unknown as { qaDescriptorState: (kind: string) => void }).qaDescriptorState('updating'))
  await expect(panel).toContainText('Обновление конфигурации ожидается')
  await page.evaluate(() => (window as unknown as { qaDescriptorState: (kind: string) => void }).qaDescriptorState('idle'))
  await expect(panel).toContainText('Предыдущая конфигурация · трансляция завершена')
  await page.evaluate(() => (window as unknown as { qaDescriptorState: (kind: string) => void }).qaDescriptorState('missing'))
  await expect(panel).toContainText('Нет подтверждения от отправителя')
  await expect(panel).not.toContainText('SDK отправителя · лимиты, не измеренный FPS')
})

for (const width of [320, 393, 1440]) {
  test(`configuration panel remains scrollable and named at ${width}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/tests/screen_profile/metadata_diagnostics.fixture.html')
    await page.getByLabel('Статистика', { exact: true }).click()
    const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
    await panel.getByText('Технические данные', { exact: true }).click()
    await expect(panel).toBeVisible()
    await expect(panel).toContainText('SDK отправителя · лимиты, не измеренный FPS')
    const bounds = await panel.boundingBox()
    expect(bounds?.x).toBeGreaterThanOrEqual(0)
    expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(width)
    const out = resolve('../../.out/qa-batch5-20261013/reader328/web')
    mkdirSync(out, { recursive: true })
    await page.screenshot({ path: resolve(out, `remote-config-${width}.png`) })
    await panel.locator('dt', { hasText: /^Опубликованная аудиодорожка$/ }).scrollIntoViewIfNeeded()
    await page.screenshot({ path: resolve(out, `remote-config-${width}-lower.png`) })
    await page.getByRole('button', { name: 'Закрыть статистику', exact: true }).last().click()
    await expect(panel).not.toBeVisible()
  })
}
