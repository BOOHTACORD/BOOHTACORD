import { test, expect } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { withBrowserZoom, captureZoomedPage } from '../control_consistency/browser_zoom'
for (const width of [1440,780]) test(`actual 200% browser zoom preserves navigation at ${width}px`, async ({ playwright }, info) => {
  let base: { width: number; outer: number; dpr: number; font: string }
  await withBrowserZoom(playwright.chromium, width, 1, async page => { await page.goto('/tests/navigation_density/fixture.html'); base = await page.evaluate(() => ({ width: innerWidth, outer: outerWidth, dpr: devicePixelRatio, font: getComputedStyle(document.documentElement).fontSize })) })
  await withBrowserZoom(playwright.chromium, width, 2, async page => {
    await page.route('**/api/v1/**', route => route.fulfill({ json: { members: [] } }))
    await page.goto('/tests/navigation_density/fixture.html'); await expect(page.locator('.channel-row')).toHaveCount(36)
    const observed = await page.evaluate(() => ({ width: innerWidth, outer: outerWidth, dpr: devicePixelRatio, font: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.documentElement).zoom, pinch: visualViewport?.scale }))
    expect(observed.outer).toBe(base.outer); expect(Math.abs(observed.width * 2 - base.width)).toBeLessThanOrEqual(2)
    expect(observed.dpr / base.dpr).toBeCloseTo(2); expect(observed.font).toBe(base.font); expect(observed.cssZoom).toBe('1'); expect(observed.pinch).toBe(1)
    await page.locator('.channel-row .channel-button').last().click()
    await expect(page.getByTestId('result')).toHaveText('channel-2-11')
    const list = await page.locator('.nav-content').boundingBox(), dock = await page.locator('.voice-dock').boundingBox()
    expect(list!.y + list!.height).toBeLessThanOrEqual(dock!.y + 1)
    await captureZoomedPage(page, info.outputPath('navigation-zoom200.png'))
    await writeFile(info.outputPath('zoom.json'), JSON.stringify(observed, null, 2))
  })
})
