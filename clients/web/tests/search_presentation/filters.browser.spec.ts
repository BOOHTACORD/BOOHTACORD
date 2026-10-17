import { expect, test } from '@playwright/test'
import { api, author, name } from './fixture_api'
test('advanced filters disclose on request; active values and reset remain available when collapsed', async ({ page }, info) => {
  await api(page)
  const reads: URLSearchParams[] = []
  await page.route('**/api/v1/search/messages?**', r => { reads.push(new URL(r.request().url()).searchParams); return r.fulfill({ json: { messages: [] } }) })
  await page.goto('/tests/search_presentation/fixture.html')
  const query = page.getByRole('searchbox', { name: 'Запрос', exact: true }), filters = page.locator('.search-filters')
  await expect(query).toBeVisible()
  await page.screenshot({ path: info.outputPath('initial-search.png') })
  await expect(filters.locator('select').first()).not.toBeVisible()
  await query.fill('orbit')
  const toggle = page.locator('.search-filter-disclosure > summary')
  await toggle.focus(); await page.keyboard.press('Enter')
  await expect(filters).toBeVisible()
  await filters.getByLabel('Автор', { exact: true }).selectOption(author)
  await filters.getByLabel('Вложения', { exact: true }).selectOption('without')
  await filters.getByLabel('С даты', { exact: true }).fill('2026-10-01')
  await toggle.click(); await expect(filters).not.toBeVisible()
  await expect(page.getByTestId('active-search-filters')).toContainText(name)
  await expect(page.getByTestId('active-search-filters')).toContainText('Без вложений')
  await expect(page.getByTestId('active-search-filters')).toContainText('2026-10-01')
  const submit = page.getByRole('button', { name: 'Найти', exact: true })
  await submit.click()
  await expect.poll(() => reads.length).toBe(1)
  await expect(submit).toHaveText('Найти')
  await expect(submit).toBeEnabled()
  expect(reads[0].get('author_id')).toBe(author); expect(reads[0].get('has_attachment')).toBe('false')
  await page.screenshot({ path: info.outputPath('active-filters-collapsed.png') })
  await page.getByRole('button', { name: 'Сбросить фильтры', exact: true }).click()
  await expect(query).toHaveValue('orbit')
  await expect(page.getByTestId('active-search-filters')).toHaveCount(0)
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  await expect.poll(() => reads.length).toBe(2)
  for (const key of ['author_id', 'has_attachment', 'created_from']) expect(reads[1].has(key)).toBe(false)
})

for (const width of [320, 390]) for (const scale of [1, 2]) test(`expanded calendar controls fit their native text at ${width}px / ${scale * 100}%`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 1000 }); await api(page)
  await page.goto('/tests/search_presentation/fixture.html')
  await page.evaluate(scale => { document.documentElement.style.fontSize = `${16 * scale}px` }, scale)
  await page.locator('.search-filter-disclosure > summary').click()
  await page.getByLabel('С даты', { exact: true }).fill('2026-10-01')
  await page.getByLabel('По дату включительно', { exact: true }).fill('2026-10-16')
  for (const field of await page.locator('.search-filters input[type=date]').all()) {
    const size = await field.evaluate(el => {
      const css = getComputedStyle(el), ctx = document.createElement('canvas').getContext('2d')!
      ctx.font = `${css.fontWeight} ${css.fontSize} ${css.fontFamily}`
      return { width: el.clientWidth, minimum: ctx.measureText('12/31/2026').width + parseFloat(css.paddingLeft) + parseFloat(css.paddingRight) + 28 }
    })
    expect(size.width).toBeGreaterThanOrEqual(size.minimum)
  }
  const geometry = await page.locator('.search-aside, .search-panel, .search-form, .search-filters, .search-filter-controls').evaluateAll(elements => elements.map(el => {
    const box = el.getBoundingClientRect()
    return { selector: el.className, left: box.left, right: box.right, width: box.width, clientWidth: el.clientWidth, scrollWidth: el.scrollWidth }
  }))
  for (const item of geometry) {
    expect(item.left, JSON.stringify(item)).toBeGreaterThanOrEqual(-1)
    expect(item.right, JSON.stringify(item)).toBeLessThanOrEqual(width + 1)
    if (/search-form|search-filters|search-filter-controls/.test(item.selector)) {
      expect(item.scrollWidth - item.clientWidth, JSON.stringify(item)).toBeLessThanOrEqual(1)
    }
  }
  await page.screenshot({ path: info.outputPath('expanded-filters.png') })
})
