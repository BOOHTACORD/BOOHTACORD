import { expect, test } from '@playwright/test'

test('real search panel keeps local day instants on pages and reopening, clears them at logout', async ({ page }, info) => {
  const reads: URLSearchParams[] = []
  await page.route('**/api/v1/members**', route => route.fulfill({ json: { members: [] } }))
  await page.route('**/api/v1/search/messages**', route => {
    const parameters = new URL(route.request().url()).searchParams
    reads.push(parameters)
    return route.fulfill({ json: { messages: [], ...(parameters.has('before') ? {} : { next_cursor: 'page-two' }) } })
  })
  await page.goto('/tests/search_dates/fixture.html')
  await page.locator('.search-filter-disclosure > summary').click()
  const start = page.getByLabel('С даты', { exact: true })
  const end = page.getByLabel('По дату включительно', { exact: true })
  await start.fill('2026-03-08')
  await end.fill('2026-03-08')
  await page.getByRole('searchbox').fill('orbit')
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  await expect.poll(() => reads.length).toBe(1)
  const ny = info.project.name === 'NewYork'
  expect(reads[0].get('created_from')).toBe(ny ? '2026-03-08T05:00:00.000Z' : '2026-03-08T00:00:00.000Z')
  expect(reads[0].get('created_before')).toBe(ny ? '2026-03-09T04:00:00.000Z' : '2026-03-09T00:00:00.000Z')
  await page.getByRole('button', { name: 'Показать ещё' }).click()
  await expect.poll(() => reads.length).toBe(2)
  expect(reads[1].get('created_from')).toBe(reads[0].get('created_from'))
  expect(reads[1].get('created_before')).toBe(reads[0].get('created_before'))
  expect(reads[1].get('before')).toBe('page-two')
  await page.getByRole('button', { name: 'Закрыть поиск' }).click()
  await page.getByRole('button', { name: 'Открыть поиск', exact: true }).click()
  await expect(start).toHaveValue('2026-03-08')
  await expect(end).toHaveValue('2026-03-08')
  await page.getByRole('button', { name: 'Завершить сессию' }).click()
  await page.getByRole('button', { name: 'Открыть поиск', exact: true }).click()
  await expect(start).toHaveValue('')
  await expect(end).toHaveValue('')
})

test('real controls use a 25-hour autumn day in New York', async ({ page }, info) => {
  let parameters: URLSearchParams | undefined
  await page.route('**/api/v1/members**', route => route.fulfill({ json: { members: [] } }))
  await page.route('**/api/v1/search/messages**', route => {
    parameters = new URL(route.request().url()).searchParams
    return route.fulfill({ json: { messages: [] } })
  })
  await page.goto('/tests/search_dates/fixture.html')
  await page.locator('.search-filter-disclosure > summary').click()
  await page.getByLabel('С даты', { exact: true }).fill('2026-11-01')
  await page.getByLabel('По дату включительно', { exact: true }).fill('2026-11-01')
  await page.getByRole('searchbox').fill('orbit')
  await page.getByRole('searchbox').press('Enter')
  await expect.poll(() => Boolean(parameters)).toBe(true)
  const duration = Date.parse(parameters!.get('created_before')!) - Date.parse(parameters!.get('created_from')!)
  expect(duration / 3_600_000).toBe(info.project.name === 'NewYork' ? 25 : 24)
})
