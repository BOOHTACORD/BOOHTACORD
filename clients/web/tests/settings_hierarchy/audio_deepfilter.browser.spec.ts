import { expect, test } from '@playwright/test'
import { join } from 'node:path'

for (const viewport of [{ width: 1440, height: 900 }, { width: 393, height: 852 }]) {
  test(`audio suppression selection at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport)
    await page.goto('/tests/settings_hierarchy/fixture.html?surface=audio')
    const selector = page.getByRole('combobox', { name: 'Режим шумоподавления' })
    await expect(selector).toHaveValue('browser')
    if (viewport.width < 600) {
      await expect(selector.locator('..')).toHaveCSS('flex-direction', 'column')
    }
    const option = selector.locator('option[value="deepfilter"]')
    if (process.env.VITE_DEEPFILTER_ENABLED === 'true') {
      await expect(option).toHaveCount(1)
      await expect(option).toHaveText('DeepFilterNet3')
      await selector.selectOption('deepfilter')
      await expect(selector).toHaveValue('deepfilter')
      await expect(page.getByText('Может повысить нагрузку процессора и задержку.')).toBeVisible()
    } else {
      await expect(option).toHaveCount(0)
    }
    if (process.env.DFN_QA_SCREENSHOT_DIR) {
      await page.screenshot({ path: join(process.env.DFN_QA_SCREENSHOT_DIR, `audio-${viewport.width}.png`), fullPage: true })
    }
  })
}

test('a saved DeepFilter choice remains visible in either build', async ({ page }) => {
  await page.goto('/tests/settings_hierarchy/fixture.html?surface=audio&noiseMode=deepfilter')
  const selector = page.getByRole('combobox', { name: 'Режим шумоподавления' })
  await expect(selector).toHaveValue('deepfilter')
  const option = selector.locator('option[value="deepfilter"]')
  if (process.env.VITE_DEEPFILTER_ENABLED === 'true') await expect(option).not.toHaveAttribute('disabled', '')
  else { await expect(option).toHaveAttribute('disabled', ''); await expect(option).toContainText('недоступен') }
})
