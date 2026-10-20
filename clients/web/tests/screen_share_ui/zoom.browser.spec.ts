import { test, expect, chromium } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { ux2026ActualZoomPhysicalViewports } from '../uiux_2026/viewport_matrix'
for (const { width } of ux2026ActualZoomPhysicalViewports) test(`share setup at actual 200% browser zoom in ${width}px`, async ({}, info) => {
  await withBrowserZoom(chromium, width, 2, async page => {
    await page.goto('http://127.0.0.1:4959/tests/screen_share_ui/fixture.html')
    const geometry = await page.evaluate(() => ({ outerWidth, innerWidth, dpr: devicePixelRatio, root: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.body).zoom, pinch: visualViewport!.scale }))
    expect(geometry).toEqual({ outerWidth: width, innerWidth: width / 2, dpr: 2, root: '16px', cssZoom: '1', pinch: 1 })
    await page.getByRole('radio', { name: '1440p' }).check()
    await expect(page.getByRole('radio', { name: '60 FPS', exact: true })).toBeDisabled()
    await expect(page.locator('.screen-share-setup__footer')).toBeInViewport({ ratio: 0.99 })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    expect(await captureZoomedPage(page, info.outputPath('launch-zoom.png')).then(png => png.readUInt32BE(16))).toBe(width)
    await page.keyboard.press('Escape')
    await expect(page.getByRole('dialog')).toHaveCount(0)
    await writeFile(info.outputPath('geometry.json'), JSON.stringify(geometry, null, 2))
  })
})
test('touch disclosure, quality and cancel stay available without hover', async ({ browser }, info) => {
  const context = await browser.newContext({ viewport: { width: 390, height: 900 }, hasTouch: true, isMobile: true })
  try {
    const page = await context.newPage()
    await page.goto('http://127.0.0.1:4959/tests/screen_share_ui/fixture.html')
    await page.getByRole('radio', { name: '720p' }).tap()
    await page.locator('.screen-share-capabilities__details > summary').tap()
    await expect(page.locator('.screen-share-capabilities__details')).toHaveAttribute('open', '')
    await page.screenshot({ path: info.outputPath('touch-details.png') })
    await page.getByRole('button', { name: 'Отмена', exact: true }).tap()
    await expect(page.getByRole('dialog')).toHaveCount(0)
  } finally { await context.close() }
})
