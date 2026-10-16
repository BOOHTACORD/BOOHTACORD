import { expect, test } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { routes } from '../microcopy/routes'

for (const width of [320, 390, 1024, 1440]) test(`settings 200% text fits ${width}px`, async ({ page }, info) => {
  await routes(page)
  await page.setViewportSize({ width, height: 1000 })
  for (const surface of ['audio', 'roles', 'profile', 'readiness']) {
    await page.goto(surface === 'audio' ? '/tests/settings_density/fixture.html' : `/tests/microcopy/fixture.html?surface=${surface === 'profile' ? 'profile' : 'admin'}&section=${surface}`)
    await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
    if (surface === 'audio') await page.locator('.audio-advanced > summary').click()
    if (surface === 'roles') await page.getByRole('checkbox', { name: 'Создавать текстовые каналы', exact: true }).uncheck()
    await page.screenshot({ path: info.outputPath(surface + '-200.png') })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    if (surface === 'audio') {
      expect(await page.locator('.audio-activation-section').evaluate(e => e.scrollWidth <= e.clientWidth)).toBe(true)
    }
    if (surface === 'roles') {
      const warning = page.locator('.role-permission-notice')
      expect(await warning.evaluate(e => e.scrollWidth <= e.clientWidth)).toBe(true)
      for (const button of await page.locator('.role-permissions .admin-section-heading button, .role-selector button').all()) {
        const rect = (await button.boundingBox())!
        expect(rect.x + rect.width).toBeLessThanOrEqual(width)
        expect(await button.evaluate(e => e.scrollWidth <= e.clientWidth)).toBe(true)
      }
    }
    const actions = page.locator(surface === 'roles' ? '.role-policy-actions' : surface === 'profile' ? '.profile-savebar' : surface === 'audio' ? '.audio-device-check__actions' : '.admin-readiness')
    for (const button of await actions.getByRole('button').all()) {
      const box = (await button.boundingBox())!
      expect(box.x).toBeGreaterThanOrEqual(0)
      expect(box.x + box.width, JSON.stringify(await button.evaluate(e => {
        const parents = []; for (let p: Element | null = e; p && parents.length < 5; p = p.parentElement) {
          const css = getComputedStyle(p); parents.push({ tag: p.className, width: p.getBoundingClientRect().width, grid: css.gridTemplateColumns, min: css.minWidth })
        } return parents
      }))).toBeLessThanOrEqual(width + 1)
      expect(box.height).toBeGreaterThanOrEqual(44)
    }
    const lastAction = actions.getByRole('button').last()
    await lastAction.scrollIntoViewIfNeeded()
    const visibleAction = (await lastAction.boundingBox())!
    expect(visibleAction.y).toBeGreaterThanOrEqual(0)
    expect(visibleAction.y + visibleAction.height).toBeLessThanOrEqual(1001)
    await page.screenshot({ path: info.outputPath(surface + '-actions-200.png') })
  }
})

test('actual browser zoom 200% retains primary settings and visible save state', async ({ playwright }, info) => {
  let before: { width: number; dpr: number }
  await withBrowserZoom(playwright.chromium, 1440, 1, async page => {
    await page.goto('http://127.0.0.1:4962/tests/settings_density/fixture.html')
    before = await page.evaluate(() => ({ width: innerWidth, dpr: devicePixelRatio }))
  })
  await withBrowserZoom(playwright.chromium, 1440, 2, async page => {
    await routes(page)
    for (const surface of ['audio', 'roles', 'profile']) {
      await page.goto('http://127.0.0.1:4962' + (surface === 'audio' ? '/tests/settings_density/fixture.html' : `/tests/microcopy/fixture.html?surface=${surface === 'profile' ? 'profile' : 'admin'}&section=roles`))
      const measured = await page.evaluate(() => ({ width: innerWidth, dpr: devicePixelRatio, font: getComputedStyle(document.documentElement).fontSize, pinch: visualViewport?.scale }))
      expect(Math.abs(measured.width * 2 - before.width)).toBeLessThanOrEqual(2)
      expect(measured.dpr / before.dpr).toBeCloseTo(2, 2)
      expect(measured.font).toBe('16px'); expect(measured.pinch).toBe(1)
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
      await captureZoomedPage(page, info.outputPath(surface + '-zoom200.png'))
      await writeFile(info.outputPath(surface + '-zoom200.json'), JSON.stringify(measured))
    }
  })
})
