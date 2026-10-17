import { expect, test } from '@playwright/test'

for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) {
  for (const scale of [1, 2]) {
    test(`four search modes fit ${width}px at ${scale * 100}% text`, async ({ page }, info) => {
      await page.setViewportSize({ width, height: 1000 })
      await page.route('**/api/v1/**', route => {
        const path = new URL(route.request().url()).pathname
        const json = path.endsWith('/pins') ? { pins: [], can_manage: false }
          : path.endsWith('/mentions') ? { mentions: [] }
          : path.endsWith('/archives/text-channels') ? { channels: [], revision: 1, can_manage: false }
          : { members: [] }
        return route.fulfill({ json })
      })
      await page.goto('/tests/search_sessions/tabs.html')
      await page.evaluate(scale => { document.documentElement.style.fontSize = `${16 * scale}px` }, scale)
      const aside = page.locator('.search-aside')
      const tabs = page.getByRole('group', { name: 'Поиск и упоминания' }).getByRole('button')
      await expect(tabs).toHaveCount(4)
      await aside.screenshot({ path: info.outputPath('search-messages.png') })
      async function checkBounds() {
        expect(await aside.evaluate(e => e.scrollWidth - e.clientWidth)).toBeLessThanOrEqual(1)
        expect(await aside.evaluate(e => e.scrollLeft)).toBe(0)
        const bounds = (await aside.boundingBox())!
        for (const tab of await tabs.all()) {
          const box = (await tab.boundingBox())!
          expect(box.x).toBeGreaterThanOrEqual(bounds.x)
          expect(box.x + box.width).toBeLessThanOrEqual(bounds.x + bounds.width + 1)
          expect(await tab.evaluate(e => e.scrollWidth - e.clientWidth)).toBeLessThanOrEqual(1)
          expect(box.height).toBeGreaterThanOrEqual(44)
        }
      }
      await checkBounds()
      const query = page.getByRole('searchbox', { name: 'Запрос', exact: true })
      await query.fill('Сохранённый запрос')
      await page.getByLabel('Область поиска').selectOption('current')
      await tabs.first().focus()
      for (let i = 0; i < 3; i++) await page.keyboard.press('Tab')
      await expect(tabs.last()).toBeFocused()
      await page.keyboard.press('Enter')
      await expect(tabs.last()).toHaveAttribute('aria-pressed', 'true')
      await expect(page.getByText('Закреплений пока нет.', { exact: true })).toBeVisible()
      await checkBounds()
      await aside.screenshot({ path: info.outputPath('search-pinned.png') })
      await page.keyboard.press('Shift+Tab')
      await expect(tabs.nth(2)).toBeFocused()
      await page.keyboard.press('Enter')
      await expect(tabs.nth(2)).toHaveAttribute('aria-pressed', 'true')
      await expect(page.getByText('Архивных каналов нет.', { exact: true })).toBeVisible()
      await checkBounds()
      await aside.screenshot({ path: info.outputPath('search-archive.png') })
      await tabs.nth(1).click()
      await expect(tabs.nth(1)).toHaveAttribute('aria-pressed', 'true')
      await expect(page.getByRole('alert')).toHaveCount(0)
      await tabs.first().click()
      await expect(query).toHaveValue('Сохранённый запрос')
      await expect(page.getByLabel('Область поиска')).toHaveValue('current')
      // Stress longer translations without changing production labels.
      await tabs.last().evaluate(e => { e.textContent = 'ОченьДлиннаяЛокализованнаяПодписьЗакреплённыхСообщений' })
      await tabs.last().focus()
      await checkBounds()
    })
  }
}

for (const width of [320, 390]) test(`touch can reach every search mode at ${width}px`, async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true })
  try {
    const page = await context.newPage()
    await page.route('**/api/v1/**', route => {
      const path = new URL(route.request().url()).pathname
      const json = path.endsWith('/pins') ? { pins: [], can_manage: false }
        : path.endsWith('/mentions') ? { mentions: [] }
          : path.endsWith('/archives/text-channels') ? { channels: [], revision: 1, can_manage: false }
            : { members: [] }
      return route.fulfill({ json })
    })
    await page.goto('/tests/search_sessions/tabs.html')
    const aside = page.locator('.search-aside')
    const tabs = page.getByRole('group', { name: 'Поиск и упоминания' }).getByRole('button')
    for (let index = 0; index < 4; index++) {
      const tab = tabs.nth(index)
      expect((await tab.boundingBox())!.height).toBeGreaterThanOrEqual(44)
      await tab.tap()
      await expect(tab).toHaveAttribute('aria-pressed', 'true')
      expect(await aside.evaluate(element => element.scrollWidth - element.clientWidth)).toBeLessThanOrEqual(1)
    }
  } finally {
    await context.close()
  }
})
