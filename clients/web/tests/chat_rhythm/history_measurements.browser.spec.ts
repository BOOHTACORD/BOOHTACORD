import { expect, test } from '@playwright/test'
import { begin, cacheSize, capture, geometry, newer, older, setup } from './history_edit_helpers'

for (const width of [1440, 393]) test(`history resize delivery stays outside observer loops at ${width}px`, async ({ page }) => {
  await page.addInitScript(() => {
    const failures: string[] = []
    Object.assign(window, { historyResizeErrors: failures })
    window.addEventListener('error', (event) => {
      if (event.message.includes('ResizeObserver loop')) failures.push(event.message)
    })
  })
  await setup(page, 500, width)
  const editor = await begin(page)
  await editor.fill('Retained edit through measured paging')
  await older(page)
  for (let index = 0; index < 3; index++) await newer(page)
  await editor.scrollIntoViewIfNeeded()
  await expect(editor).toHaveValue('Retained edit through measured paging')
  await expect.poll(() => cacheSize(page)).toBe(500)
  expect((await geometry(page)).rows).toBeLessThan(64)
  await capture(page, `measured-history-${width}`)
  await page.setViewportSize({ width: width === 1440 ? 1024 : 430, height: 800 })
  await expect(editor).toHaveValue('Retained edit through measured paging')
  await page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))))
  expect(await page.evaluate(() => (window as unknown as { historyResizeErrors: string[] }).historyResizeErrors)).toEqual([])
  await capture(page, `measured-history-resized-${page.viewportSize()!.width}`)
})
