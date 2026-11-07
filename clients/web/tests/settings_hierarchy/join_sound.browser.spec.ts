import { expect, test } from '@playwright/test'
import { routes } from '../microcopy/routes'

for (const width of [320, 390, 432]) test(`join melody fits enlarged text at ${width}px`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  await routes(page)
  await page.route('**/api/v1/me/join-sound', route => route.fulfill({ status: 404, json: { error: { code: 'NOT_FOUND' } } }))
  await page.goto('/tests/settings_hierarchy/fixture.html?surface=profile&scale=200')
  await page.evaluate(() => document.fonts.ready)
  const panel = page.getByRole('region', { name: 'Персональная мелодия входа', exact: true })
  await expect(panel).toBeVisible()
  const geometry = await panel.evaluate(element => Array.from(element.querySelectorAll('h3,p,label,input,button')).map(child => {
    const rect = child.getBoundingClientRect()
    return { tag: child.tagName, left: rect.left, right: rect.right, scroll: child.scrollWidth, width: child.clientWidth }
  }))
  for (const item of geometry) {
    expect(item.left, JSON.stringify(item)).toBeGreaterThanOrEqual(0)
    expect(item.right, JSON.stringify(item)).toBeLessThanOrEqual(width)
    if (item.tag !== 'INPUT') expect(item.scroll, JSON.stringify(item)).toBeLessThanOrEqual(item.width + 1)
  }
  await page.screenshot({ path: info.outputPath('join-melody-large-text.png'), fullPage: true })
})
