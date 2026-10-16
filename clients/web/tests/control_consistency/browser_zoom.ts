import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import type { BrowserType, Page } from '@playwright/test'

// At native page zoom, Chromium's screenshot clip uses DIP contentSize rather
// than cssContentSize. Playwright's fullPage clip otherwise crops physical paint
// to the CSS width (390px PNG for a 780px window at 200%). Capture the browser's
// unmodified paint; callers assert the PNG width against the observed DPR.
export async function captureZoomedPage(page: Page, path: string): Promise<Buffer> {
  const session = await page.context().newCDPSession(page)
  try {
    const { contentSize } = await session.send('Page.getLayoutMetrics')
    const { data } = await session.send('Page.captureScreenshot', {
      format: 'png', captureBeyondViewport: true, clip: { ...contentSize, scale: 1 },
    })
    const png = Buffer.from(data, 'base64')
    await writeFile(path, png)
    return png
  } finally { await session.detach() }
}

// Actual browser page zoom, independently verified by layout viewport and DPR.
// No CSS zoom, font scaling, pinch emulation or personal browser profile.
// Chromium: chrome/browser/ui/zoom/chrome_zoom_level_prefs.cc and
// third_party/blink/common/page/page_zoom.cc (factor = 1.2 ** zoom_level).
export async function withBrowserZoom(browser: BrowserType, width: number, factor: number, run: (page: Page) => Promise<void>) {
  const profile = await mkdtemp(join(tmpdir(), 'boohtacord-controls-zoom-'))
  let context: Awaited<ReturnType<BrowserType['launchPersistentContext']>> | undefined
  try {
    await mkdir(join(profile, 'Default'))
    await writeFile(join(profile, 'Default', 'Preferences'), JSON.stringify({
      partition: { default_zoom_level: { x: Math.log(factor) / Math.log(1.2) } },
    }))
    context = await browser.launchPersistentContext(profile, {
      headless: true, viewport: null, args: [`--window-size=${width},1000`],
      ...(process.env.CHROMIUM_EXECUTABLE_PATH ? { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } : { channel: 'chromium' }),
    })
    await run(context.pages()[0] ?? await context.newPage())
  } finally {
    await context?.close()
    await rm(profile, { recursive: true, force: true })
  }
}
