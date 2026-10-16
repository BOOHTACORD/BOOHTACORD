import { expect, openNavigation } from './request.mjs'

// Four-mode search regression against the owned API, with real touch on mobile.
export async function searchTabs(page, input, report) {
  await openNavigation(page)
  await page.locator('.guild-search-button').click()
  const aside = page.locator('.search-aside')
  const panel = page.getByTestId('search-panel')
  const tabs = panel.locator('.search-view-tabs button')
  await expect(tabs).toHaveCount(4)
  const query = panel.getByRole('searchbox', { name: 'Запрос', exact: true })
  await query.fill('Synthetic preserved search')
  async function bounds() {
    expect(await aside.evaluate(e => e.scrollWidth - e.clientWidth)).toBeLessThanOrEqual(1)
    expect(await aside.evaluate(e => e.scrollLeft)).toBe(0)
    const edge = await aside.boundingBox()
    for (const tab of await tabs.all()) {
      const box = await tab.boundingBox()
      expect(box.x).toBeGreaterThanOrEqual(edge.x)
      expect(box.x + box.width).toBeLessThanOrEqual(edge.x + edge.width + 1)
    }
  }
  await bounds()
  await page.screenshot({ path: input.directory + '/search-tabs-messages.png' })
  await tabs.first().focus()
  for (let i = 0; i < 3; i++) await page.keyboard.press('Tab')
  await expect(tabs.last()).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(tabs.last()).toHaveAttribute('aria-pressed', 'true')
  await expect(panel.locator('.pin-panel > button').first()).toBeEnabled()
  await expect(panel.getByRole('alert')).toHaveCount(0)
  await bounds()
  await page.screenshot({ path: input.directory + '/search-tabs-pinned.png' })
  for (const [index, name, selector] of [[2, 'archive', '.archive-panel'], [1, 'mentions', '.mention-inbox']]) {
    if (input.viewport.has_touch) await tabs.nth(index).tap()
    else await tabs.nth(index).click()
    await expect(tabs.nth(index)).toHaveAttribute('aria-pressed', 'true')
    await expect(panel.locator(selector).getByRole('button').first()).toBeEnabled()
    await expect(panel.getByRole('alert')).toHaveCount(0)
    await bounds()
    await page.screenshot({ path: input.directory + `/search-tabs-${name}.png` })
  }
  await tabs.first().click()
  await expect(query).toHaveValue('Synthetic preserved search')
  await panel.getByRole('button', { name: 'Закрыть поиск', exact: true }).click()
  report.search_tabs = { four_modes: true, no_horizontal_overflow: true, keyboard_last_tab: true, touch: input.viewport.has_touch, query_retained: true }
}
