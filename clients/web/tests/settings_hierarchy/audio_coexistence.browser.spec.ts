import { expect, test } from '@playwright/test'
import { routes } from '../microcopy/routes'

test.use({ userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36' })

for (const width of [320, 800]) test.describe(`Windows audio help at ${width}px`, () => {
  test.use({ userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36' })
  test('discloses system attenuation guidance and retains audio controls', async ({ page }, info) => {
    await page.setViewportSize({ width, height: 600 })
    await routes(page)
    await page.goto(`/tests/settings_hierarchy/fixture.html?surface=audio&scale=${width === 320 ? 200 : 100}`)
    const help = page.locator('details').filter({ hasText: 'Музыка становится тише' })
    await expect(help).toHaveCount(1)
    await expect(help).not.toHaveAttribute('open', '')
    await help.locator('summary').focus()
    await page.keyboard.press('Enter')
    await expect(help).toHaveAttribute('open', '')
    await expect(help.locator('p')).toContainText('Панель управления → Звук → Связь')
    await expect(help.locator('p')).toContainText('Действие не требуется')
    await expect(help.locator('p')).toContainText('Браузер не может изменить')
    await page.screenshot({ path: info.outputPath(`windows-audio-help-${width}.png`), fullPage: true })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    await help.locator('summary').press('Enter')
    await expect(help).not.toHaveAttribute('open', '')
    await page.locator('.audio-advanced summary').click()
    await expect(page.locator('.audio-advanced')).toHaveAttribute('open', '')
    const noise = page.getByRole('combobox', { name: 'Режим шумоподавления', exact: true })
    await noise.selectOption('off')
    await expect(noise).toHaveValue('off')
  })
})

test('non-Windows clients do not show Windows system settings', async ({ page }) => {
  await routes(page)
  await page.goto('/tests/settings_hierarchy/fixture.html?surface=audio')
  await expect(page.getByText('Музыка становится тише при подключении к голосовому каналу?')).toHaveCount(0)
  await expect(page.getByRole('combobox', { name: 'Режим шумоподавления', exact: true })).toBeVisible()
})
