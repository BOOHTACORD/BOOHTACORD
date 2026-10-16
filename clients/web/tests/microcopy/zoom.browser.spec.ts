import { expect, test, type Page } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { routes } from './routes'

const observe = (page: Page) => page.evaluate(() => ({ width: innerWidth, outer: outerWidth, dpr: devicePixelRatio,
  font: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.documentElement).zoom,
  pinch: visualViewport?.scale, horizontalOverflow: document.documentElement.scrollWidth > innerWidth }))

for (const width of [1440, 780]) test(`actual page zoom 200% keeps copy and focused hints usable at ${width}px`, async ({ playwright }, info) => {
  let before: Awaited<ReturnType<typeof observe>>
  await withBrowserZoom(playwright.chromium, width, 1, async page => {
    await routes(page); await page.goto('/tests/microcopy/fixture.html?surface=prejoin'); before = await observe(page)
  })
  await withBrowserZoom(playwright.chromium, width, 2, async page => {
    await routes(page)
    for (const surface of ['prejoin', 'audio', 'profile', 'chat', 'dm', 'search', 'share']) {
      await page.goto(`/tests/microcopy/fixture.html?surface=${surface}`)
      await page.evaluate(() => document.fonts.ready)
      const zoomed = await observe(page)
      expect(zoomed.outer).toBe(before.outer)
      expect(Math.abs(zoomed.width * 2 - before.width)).toBeLessThanOrEqual(2)
      expect(zoomed.dpr / before.dpr).toBeCloseTo(2, 2)
      expect(zoomed.font).toBe(before.font); expect(zoomed.cssZoom).toBe(before.cssZoom); expect(zoomed.pinch).toBe(1)
      if (surface !== 'search') expect(zoomed.horizontalOverflow).toBe(false)
      // #340 owns existing search-tab overflow. Keep the full uncropped browser
      // image and explicit overflow flag; only changed form bounds are asserted.
      if (surface === 'search') {
        const form = await page.locator('.search-form').boundingBox()
        expect(form!.x + form!.width).toBeLessThanOrEqual(zoomed.width + 1)
      }
      if (surface === 'audio') {
        const help = page.getByText('О настройках аудио', { exact: true })
        await help.focus(); await help.press('Enter')
        await expect(page.getByText('Настройки действуют на этом устройстве.', { exact: true })).toBeVisible()
      }
      if (surface === 'chat' || surface === 'dm') {
        const trigger = page.getByRole('button', { name: 'Другие действия', exact: true })
        await trigger.focus(); await trigger.press('Tab'); await page.keyboard.press('Shift+Tab')
        const hint = page.getByRole('tooltip')
        await expect(hint).toBeVisible()
        const box = await hint.boundingBox()
        expect(box!.x).toBeGreaterThanOrEqual(8)
        expect(box!.x + box!.width).toBeLessThanOrEqual(zoomed.width - 7)
        await page.keyboard.press('Escape'); await expect(hint).toHaveCount(0)
      }
      await captureZoomedPage(page, info.outputPath(`${surface}-zoom200-${width}.png`))
      await writeFile(info.outputPath(`${surface}-zoom200-${width}.json`), JSON.stringify({ surface, before, zoomed }))
    }
  })
})
