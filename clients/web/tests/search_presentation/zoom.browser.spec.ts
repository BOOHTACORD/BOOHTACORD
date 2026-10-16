import { test, expect, chromium } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
import { api, channel } from './fixture_api'
for (const width of [640, 780, 2048, 2880]) test(`six result surfaces at actual 200% browser zoom in ${width}px`, async ({}, info) => {
  await withBrowserZoom(chromium, width, 2, async page => {
    await api(page)
    for (const surface of ['search', 'pins', 'archive', 'mentions', 'quick', 'files']) {
      await page.goto(`http://127.0.0.1:4956/tests/search_presentation/fixture.html?surface=${surface}`)
      if (surface === 'search') {
        await page.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('orbit')
        await page.getByRole('button', { name: 'Найти', exact: true }).click()
      }
      for (const [mode, label] of [['pins', 'Закреплённые'], ['archive', 'Архив'], ['mentions', 'Упоминания']]) {
        if (surface === mode) await page.getByRole('group', { name: 'Поиск и упоминания' }).getByRole('button', { name: label, exact: true }).click()
      }
      if (surface === 'archive') await page.getByRole('combobox', { name: 'Канал', exact: true }).selectOption(channel)
      await expect(page.locator('.result-row').first()).toBeVisible()
      const geometry = await page.evaluate(() => ({ outerWidth, innerWidth, dpr: devicePixelRatio, root: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.body).zoom, pinch: visualViewport!.scale }))
      expect(geometry).toEqual({ outerWidth: width, innerWidth: width / 2, dpr: 2, root: '16px', cssZoom: '1', pinch: 1 })
      const rail = page.locator('.search-aside')
      expect(await rail.evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
      for (const owner of await page.locator('#search-mode-content,.conversation-files,.quick-jump-results').all()) {
        expect(await owner.evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
      }
      const target = surface === 'files' ? page.locator('.file-name-detail summary').first()
        : surface === 'archive' ? page.locator('.archive-panel .result-toolbar button')
        : page.locator('.result-row button').first()
      await target.focus(); await expect(target).toBeInViewport()
      const png = await captureZoomedPage(page, info.outputPath(`${surface}-zoom.png`))
      expect(png.readUInt32BE(16)).toBe(width)
      await writeFile(info.outputPath(`${surface}-zoom.json`), JSON.stringify(geometry, null, 2))
    }
  })
})

for (const width of [320, 390]) test(`touch filters, modes, quick jump and file details at ${width}px`, async ({ browser }, info) => {
  const context = await browser.newContext({ viewport: { width, height: 900 }, hasTouch: true, isMobile: true })
  try {
    const page = await context.newPage(); await api(page)
    await page.goto('http://127.0.0.1:4956/tests/search_presentation/fixture.html')
    await page.locator('.search-filter-disclosure > summary').tap()
    await expect(page.getByLabel('Автор', { exact: true })).toBeVisible()
    for (const label of ['Закреплённые', 'Архив', 'Упоминания', 'Сообщения']) {
      const target = page.getByRole('group', { name: 'Поиск и упоминания' }).getByRole('button', { name: label, exact: true })
      await target.tap(); await expect(target).toHaveAttribute('aria-pressed', 'true')
    }
    await page.goto('http://127.0.0.1:4956/tests/search_presentation/fixture.html?surface=quick')
    await page.locator('.result-row button').first().tap()
    await expect(page.getByTestId('action')).toHaveText(channel)
    await page.goto('http://127.0.0.1:4956/tests/search_presentation/fixture.html?surface=files')
    await page.locator('.file-name-detail summary').first().tap()
    await expect(page.locator('.file-name-detail p').first()).toBeVisible()
    await page.screenshot({ path: info.outputPath('touch-file-details.png') })
  } finally { await context.close() }
})
