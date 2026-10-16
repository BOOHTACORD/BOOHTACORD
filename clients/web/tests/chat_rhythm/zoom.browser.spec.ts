import { test, expect, chromium } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { kinds, mount, expectWithinViewport, row } from './helpers'
for (const kind of kinds) for (const width of [780, 1440]) {
  test(`actual 200% browser zoom ${kind} ${width}px window`, async ({}, info) => {
    await withBrowserZoom(chromium, width, 2, async page => {
      await mount(page, kind)
      const geometry = await page.evaluate(() => ({ outerWidth, innerWidth, dpr: devicePixelRatio,
        rootFont: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.body).zoom,
        pinch: visualViewport!.scale }))
      expect(geometry.outerWidth).toBe(width)
      expect(geometry.innerWidth).toBe(width / 2)
      expect(geometry.dpr).toBe(2)
      expect(geometry.rootFont).toBe('16px')
      expect(geometry.cssZoom).toBe('1')
      expect(geometry.pinch).toBe(1)
      await expectWithinViewport(page)
      const png = await captureZoomedPage(page, info.outputPath('zoom-200-history.png'))
      expect(png.readUInt32BE(16)).toBe(width)
      await row(page, 11).scrollIntoViewIfNeeded()
      await expectWithinViewport(page)
      await captureZoomedPage(page, info.outputPath('zoom-200-rich-text.png'))
      await writeFile(info.outputPath('zoom.json'), JSON.stringify(geometry, null, 2))
    })
  })
}
