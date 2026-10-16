import { expect, test } from '@playwright/test'

for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
  test(`actual search button remains pointer reachable below filters at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport)
    const reads: URLSearchParams[] = []
    await page.route('**/api/v1/members**', route => route.fulfill({ json: { members: [] } }))
    await page.route('**/api/v1/search/messages**', route => {
      reads.push(new URL(route.request().url()).searchParams)
      return route.fulfill({ json: { messages: [] } })
    })
    await page.goto('/tests/search_dates/fixture.html')
  await page.locator('.search-filter-disclosure > summary').click()
    await page.getByLabel('С даты', { exact: true }).fill('2026-03-08')
    await page.getByLabel('По дату включительно', { exact: true }).fill('2026-03-08')
    await page.getByRole('searchbox').fill('orbit')
    const button = page.getByRole('button', { name: 'Найти', exact: true })
    await expect(button).toBeEnabled()
    const bounds = await button.boundingBox()
    expect(bounds!.height).toBeGreaterThanOrEqual(44)
    expect(bounds!.width).toBeGreaterThanOrEqual(44)
    const filters = await page.locator('.search-filters').boundingBox()
    expect(bounds!.y).toBeGreaterThanOrEqual(filters!.y + filters!.height)
    expect(await button.evaluate(element => {
      const rect = element.getBoundingClientRect()
      return element.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2))
    })).toBe(true)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    await button.click({ timeout: 3000 })
    await expect.poll(() => reads.length).toBe(1)
    expect(reads[0]!.get('query')).toBe('orbit')
    expect(reads[0]!.get('created_from')).toBeTruthy()
    expect(reads[0]!.get('created_before')).toBeTruthy()
  })
}
