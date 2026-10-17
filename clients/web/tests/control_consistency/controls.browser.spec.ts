import { expect, test, type Locator, type Page } from '@playwright/test'
import { expectAxeClear } from '../accessibility/axe'
import { fixtureRoutes, id } from './routes'
import { captureZoomedPage, withBrowserZoom } from './browser_zoom'
import { writeFile } from 'node:fs/promises'

const surfaces = ['guild', 'audio', 'archive', 'quick', 'files'] as const
async function expectControlsFit(page: Page) {
  const bounds = await page.locator('.gc-button:visible, .gc-field:visible').evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect()
    const style = getComputedStyle(element)
    const parent = element.parentElement?.getBoundingClientRect()
    const parents = [element.parentElement, element.parentElement?.parentElement, element.parentElement?.parentElement?.parentElement]
      .filter((node): node is HTMLElement => node instanceof HTMLElement)
      .map(node => `${node.tagName.toLowerCase()}.${String(node.className)}=${node.getBoundingClientRect().width}/${getComputedStyle(node).minWidth}`)
    return { left: rect.left, right: rect.right, viewport: innerWidth,
      target: `${element.tagName.toLowerCase()}.${String(element.className)} ${element.getAttribute('aria-label') ?? element.textContent?.trim().replace(/\s+/g, ' ').slice(0, 60)} (${Math.round(rect.left)}..${Math.round(rect.right)} / ${innerWidth}; css=${style.width},min=${style.minWidth},max=${style.maxWidth},box=${style.boxSizing},parent=${parent?.width}; ancestors=${parents.join(' <- ')})`,
      clippedText: element.matches('button') && element.scrollWidth > element.clientWidth + 2 }
  }))
  for (const bound of bounds) {
    expect(bound.left, bound.target).toBeGreaterThanOrEqual(-1)
    expect(bound.right, bound.target).toBeLessThanOrEqual(bound.viewport + 1)
    expect(bound.clippedText, bound.target).toBe(false)
  }
}
async function open(page: Page, surface: string, scale = 100) {
  await fixtureRoutes(page)
  await page.goto(`/tests/control_consistency/fixture.html?surface=${surface}&scale=${scale}`)
  if (surface === 'guild') { await expect(page.getByLabel('Название гильдии', { exact: true })).toBeEnabled(); await page.getByLabel('Название гильдии', { exact: true }).fill('Новая гильдия') }
  if (surface === 'audio') { await page.getByText('Дополнительно', { exact: true }).click(); await page.getByText('Режим и диагностика обработки', { exact: true }).click() }
  if (surface === 'archive') { await expect(page.getByLabel('Канал', { exact: true })).toBeVisible(); await page.getByLabel('Канал', { exact: true }).selectOption(id) }
  if (surface === 'files') await expect(page.locator('.conversation-files .result-row')).toHaveCount(1)
  await page.evaluate(() => document.fonts.ready)
}
function action(page: Page, surface: string): Locator {
  return surface === 'guild' ? page.getByRole('button', { name: 'Сохранить', exact: true })
    : surface === 'audio' ? page.getByRole('button', { name: 'Сбросить громкость участников и трансляций', exact: true })
      : surface === 'archive' ? page.getByRole('button', { name: 'Вся история', exact: true })
        : surface === 'quick' ? page.getByRole('button', { name: 'Показать ещё участников', exact: true })
          : page.getByRole('button', { name: /^Перейти к сообщению с файлом/ })
}
for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) for (const scale of [100, 200]) for (const surface of surfaces) {
  test(`${surface} coherent controls ${width}px / ${scale}% text`, async ({ page }, info) => {
    await page.setViewportSize({ width, height: 900 })
    await open(page, surface, scale)
    await page.screenshot({ path: info.outputPath(`${surface}-${width}-${scale}.png`), fullPage: true })
    if (surface === 'audio') {
      const diagnostics = page.getByText('Диагностика качества голоса', { exact: true })
      await diagnostics.click()
      await diagnostics.locator('..').screenshot({ path: info.outputPath(`audio-diagnostics-${width}-${scale}.png`) })
    }
    const control = action(page, surface)
    const style = await control.evaluate(element => {
      const s = getComputedStyle(element), r = element.getBoundingClientRect()
      return { background: s.backgroundColor, radius: s.borderRadius, height: r.height, width: r.width }
    })
    // The previous browser-default grey actions have no Design V2 radius/surface.
    expect(style.radius).toBe('8px')
    expect(style.background).toBe(surface === 'guild' ? 'rgb(88, 101, 242)' : 'rgb(34, 38, 49)')
    expect(style.height).toBeGreaterThanOrEqual(width <= 600 ? 44 : 36)
    for (const field of await page.locator('input:not([type=range]):not([type=checkbox]):not([type=radio]), select').all()) {
      await expect(field).toHaveCSS('background-color', 'rgb(26, 29, 38)')
      await expect(field).toHaveCSS('border-radius', '8px')
      const box = await field.boundingBox()
      expect(box!.height).toBeGreaterThanOrEqual(44 * scale / 100)
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    await expectControlsFit(page)
    await control.focus()
    await control.press('Tab'); await page.keyboard.press('Shift+Tab')
    await expect(control).toBeFocused()
    expect(await control.evaluate(e => e.matches(':focus-visible'))).toBe(true)
    expect(await control.evaluate(e => getComputedStyle(e).outlineStyle)).toBe('solid')
    if (surface === 'guild') { await control.press('Enter'); await expect(page.locator('.guild-settings').getByRole('status')).toContainText('сохранены') }
    if (surface === 'audio') { await control.press('Enter'); await expect(control).toBeDisabled(); await expect(control).toBeEnabled(); await expect(page.getByTestId('action')).toHaveText('reset') }
    if (surface === 'quick') { await control.press('Enter'); await expect(page.getByTestId('action')).toHaveText('next') }
    if (surface === 'files') { await control.press('Enter'); await expect(page.getByTestId('action')).toHaveText('open') }
    await expectAxeClear(page, 'main')
  })
}

for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) test(`semantic variants, hover, focus and disabled actions ${width}px`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  await open(page, 'variants')
  const primary = page.getByRole('button', { name: 'primary', exact: true })
  const secondary = page.getByRole('button', { name: 'secondary', exact: true })
  const danger = page.getByRole('button', { name: 'danger', exact: true })
  await expect(primary).toHaveCSS('background-color', 'rgb(88, 101, 242)')
  await primary.hover()
  await expect(primary).toHaveCSS('background-color', 'rgb(71, 82, 196)')
  await secondary.hover()
  await expect(secondary).toHaveCSS('background-color', 'rgb(39, 44, 57)')
  await danger.focus(); await danger.press('Enter')
  await expect(page.getByTestId('action')).toHaveText('danger')
  const disabled = page.getByRole('button', { name: 'Недоступно' })
  await expect(disabled).toBeDisabled()
  const bounds = await disabled.boundingBox()
  await page.mouse.click(bounds!.x + bounds!.width / 2, bounds!.y + bounds!.height / 2)
  await expect(page.getByTestId('action')).toHaveText('danger')
  await expect(page.getByRole('button', { name: 'Сохраняем…' })).toHaveAttribute('aria-busy', 'true')
  const icon = page.getByRole('button', { name: 'Закрыть пример' })
  await expect(icon).toHaveAttribute('title', 'Закрыть пример')
  const box = await icon.boundingBox(); expect(box!.width).toBe(box!.height)
  await expectAxeClear(page, 'main')
  await page.screenshot({ path: info.outputPath(`variants-${width}.png`), fullPage: true })
})

for (const width of [320, 390]) test(`coarse-pointer actions stay usable across all surfaces at ${width}px`, async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width, height: 900 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true })
  try {
    const page = await context.newPage()
    for (const surface of surfaces) {
      await open(page, surface)
      const control = action(page, surface)
      await expect(control).toBeVisible()
      expect((await control.boundingBox())!.height).toBeGreaterThanOrEqual(44)
      await control.tap()
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
      await expectControlsFit(page)
    }
  } finally {
    await context.close()
  }
})

for (const physicalWidth of [1440, 780]) test(`actual browser zoom 200% at ${physicalWidth}px`, async ({ playwright }, info) => {
  const read = (page: Page) => page.evaluate(() => ({
    width: innerWidth, outer: outerWidth, dpr: devicePixelRatio,
    pinch: visualViewport?.scale, font: getComputedStyle(document.documentElement).fontSize,
    cssZoom: getComputedStyle(document.documentElement).zoom,
  }))
  let before: Awaited<ReturnType<typeof read>>
  await withBrowserZoom(playwright.chromium, physicalWidth, 1, async page => {
    await open(page, 'guild'); before = await read(page)
  })
  await withBrowserZoom(playwright.chromium, physicalWidth, 2, async page => {
    for (const surface of surfaces) {
      await open(page, surface)
      if (surface === 'audio') await page.getByText('Диагностика качества голоса', { exact: true }).click()
      const zoomed = await read(page)
      expect(zoomed.outer).toBe(before.outer)
      expect(Math.abs(zoomed.width * 2 - before.width)).toBeLessThanOrEqual(2)
      expect(zoomed.dpr / before.dpr).toBeCloseTo(2, 2)
      expect(zoomed.pinch).toBe(1)
      expect(zoomed.font).toBe(before.font)
      expect(zoomed.cssZoom).toBe(before.cssZoom)
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
      await expectControlsFit(page)
      await action(page, surface).scrollIntoViewIfNeeded()
      await expect(action(page, surface)).toBeInViewport()
      await expectAxeClear(page, 'main')
      const png = await captureZoomedPage(page, info.outputPath(`zoom200-${physicalWidth}-${surface}.png`))
      expect(png.readUInt32BE(16)).toBe(Math.round(zoomed.width * zoomed.dpr))
      await writeFile(info.outputPath(`zoom200-${physicalWidth}-${surface}.json`), JSON.stringify({ before, zoomed }))
    }
  })
})
