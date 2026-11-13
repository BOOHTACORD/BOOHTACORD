import { expect, type Page } from '@playwright/test'
import { routes } from '../microcopy/routes'

export async function open(page: Page, scene: string, scale = 100) {
  await routes(page)
  await page.goto(`/tests/settings_hierarchy/fixture.html?surface=${scene}&scale=${scale}`)
  const params = new URLSearchParams(`surface=${scene}`)
  if (params.get('tab')) await page.getByRole('tab', { name: params.get('tab')!, exact: true }).click()
  if (scene.includes('section=guild')) await expect(page.getByLabel('Название гильдии', { exact: true })).toBeEnabled()
  if (scene.includes('section=roles')) await expect(page.getByRole('tab', { name: 'Пользователь', exact: true })).toBeVisible()
  if (params.has('advanced')) await page.getByText('Диагностика', { exact: true }).click()
  await page.evaluate(() => document.fonts.ready)
}
export async function fit(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  for (const row of await page.locator('label:visible, button:visible, summary:visible').evaluateAll(es => es.filter(e=>!e.closest('nav') && e.checkVisibility({opacityProperty:true})).map(e => {
    const r=e.getBoundingClientRect();return { text:e.textContent?.trim().slice(0,60), left:r.left, right:r.right, width:innerWidth, clipped:e.tagName==='BUTTON' && e.scrollWidth>e.clientWidth+2 }
  }))) { expect(row.left).toBeGreaterThanOrEqual(-1); expect(row.right).toBeLessThanOrEqual(row.width+1); expect(row.clipped,JSON.stringify(row)).toBe(false) }
}
