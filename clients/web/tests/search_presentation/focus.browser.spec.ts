import { expect, test } from '@playwright/test'
import { api, message, id } from './fixture_api'
test('keyboard focus reveals the full source and author of a truncated search result', async ({ page }) => {
  await api(page)
  await page.goto('/tests/search_presentation/fixture.html')
  await page.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('orbit')
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  const row = page.locator('.search-result').first()
  await row.getByRole('button').focus()
  for (const field of ['.result-source', '.search-result-author strong']) {
    expect(await row.locator(field).evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
  }
})

for (const width of [320, 390]) test(`a late matching snippet stays visible with 200% text and no clipped link at ${width}px`, async ({ page }) => {
  await page.setViewportSize({ width, height: 1000 })
  await api(page)
  await page.route('**/api/v1/search/messages?**', r => r.fulfill({ json: { messages: [{
    ...message(1), kind: 'CHANNEL', body: '😀'.repeat(100) + '[Orbit](https://example.org/target) nearby context',
  }] } }))
  await page.goto('/tests/search_presentation/fixture.html')
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
  await page.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('orbit')
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  const row = page.locator('.search-result').first()
  await expect(row.locator('.search-result-body a')).toHaveCount(0)
  await expect(row.locator('mark')).toHaveText('Orbit')
  const ink = (await row.locator('mark').boundingBox())!, excerpt = (await row.locator('.search-result-body').boundingBox())!
  expect(ink.height).toBeGreaterThan(0)
  expect(ink.y + ink.height).toBeLessThanOrEqual(excerpt.y + excerpt.height + 1)
  await expect(row.locator('.search-result-body')).toContainText('nearby context')
  await row.getByRole('button').focus(); await page.keyboard.press('Enter')
  await expect(page.getByTestId('action')).toHaveText(id(1))
})

for (const width of [320, 390]) test(`late multiword web-search terms remain in the clipped preview at ${width}px`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 1000 }); await api(page)
  await page.route('**/api/v1/search/messages?**', r => r.fulfill({ json: { messages: [{
    ...message(1), kind: 'CHANNEL', body: 'unrelated '.repeat(100) + 'Orbit launch tomorrow',
  }] } }))
  await page.goto('/tests/search_presentation/fixture.html')
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
  await page.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('orbit tomorrow')
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  const row = page.locator('.search-result').first()
  await expect(row.locator('mark')).toHaveText(['Orbit', 'tomorrow'])
  await row.locator('.search-result-body').scrollIntoViewIfNeeded()
  await expect(row.locator('mark').first()).toBeInViewport()
  await expect(row.locator('mark').last()).toBeInViewport()
  const excerpt = (await row.locator('.search-result-body').boundingBox())!
  for (const match of await row.locator('mark').all()) {
    const ink = (await match.boundingBox())!
    expect(ink.y + ink.height).toBeLessThanOrEqual(excerpt.y + excerpt.height + 1)
  }
  await page.screenshot({ path: info.outputPath('multiword-preview.png') })
})
