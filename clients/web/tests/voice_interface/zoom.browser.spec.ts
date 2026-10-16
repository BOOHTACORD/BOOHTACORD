import { test, expect, chromium } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'

for (const width of [640, 780, 2048, 2880]) test(`voice at actual 200% browser zoom in ${width}px`, async ({}, info) => {
  await withBrowserZoom(chromium, width, 2, async page => {
    await page.route('**/api/**', route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
    await page.goto('http://127.0.0.1:4957/tests/voice_interface/fixture.html')
    await expect(page.locator('.voice-room-controls')).toBeVisible()
    const geometry = await page.evaluate(() => ({ outerWidth, innerWidth, dpr: devicePixelRatio, root: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.body).zoom, pinch: visualViewport!.scale }))
    expect(geometry).toEqual({ outerWidth: width, innerWidth: width / 2, dpr: 2, root: '16px', cssZoom: '1', pinch: 1 })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    const mute = page.locator('.voice-room-controls button').first()
    await mute.focus(); await page.keyboard.press('Space')
    await expect(mute).toHaveAttribute('data-state', 'muted')
    expect(await captureZoomedPage(page, info.outputPath('muted-zoom.png')).then(png => png.readUInt32BE(16))).toBe(width)
    await page.evaluate(() => (window as any).__voiceFixture.patch({ active: false, state: 'IDLE' }))
    const listener = page.getByRole('button', { name: 'Без микрофона', exact: true })
    await listener.focus(); await expect(listener).toBeInViewport()
    await captureZoomedPage(page, info.outputPath('prejoin-zoom.png'))
    await writeFile(info.outputPath('geometry.json'), JSON.stringify(geometry, null, 2))
  })
})

test('touch primary controls need no disclosure and secondary details open deliberately', async ({ browser }, info) => {
  const context = await browser.newContext({ viewport: { width: 390, height: 900 }, hasTouch: true, isMobile: true })
  try {
    const page = await context.newPage()
    await page.route('**/api/**', route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
    await page.goto('http://127.0.0.1:4957/tests/voice_interface/fixture.html')
    const room = page.locator('.room-wrap')
    await room.getByRole('button', { name: 'Выключить микрофон', exact: true }).tap()
    await expect(room.locator('[data-state=muted]')).toBeVisible()
    await room.locator('.voice-advanced > summary').tap()
    await expect(room.getByText('Микрофон и звук трансляции управляются отдельно.', { exact: true })).toBeVisible()
    await page.locator('.voice-connection-details > summary').tap()
    await expect(page.getByTestId('voice-dock').getByText('42 мс', { exact: true })).toBeVisible()
    await page.screenshot({ path: info.outputPath('touch-details.png'), fullPage: true })
  } finally { await context.close() }
})
