import { test, expect, type Page } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import axe from 'axe-core'
import {
  ux2026BreakpointViewports,
  ux2026EdgeViewports,
  ux2026RequiredViewports,
} from '../uiux_2026/viewport_matrix'
const longName = 'Обсуждение очень длинного названия канала для совместной работы'
async function open(page: Page, member = false) {
  await page.route('**/api/v1/**', route => route.fulfill({ json: { members: [] } }))
  await page.goto(`/tests/navigation_density/fixture.html?member=${member ? 1 : 0}`)
  await expect(page.locator('.channel-row')).toHaveCount(36)
  await page.evaluate(() => document.fonts.ready)
}
async function markerColor(page: Page, selector: string): Promise<string> {
  return page.locator(selector).evaluate(el => getComputedStyle(el).boxShadow.match(/rgba?\([^)]*\)/)?.[0] ?? 'none')
}
async function geometry(page: Page) {
  return page.evaluate(() => {
    const nav = document.querySelector<HTMLElement>('.nav-content')!
    const bounds = (selector: string) => { const r = document.querySelector(selector)!.getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height, bottom: r.bottom } }
    return { viewport: { width: innerWidth, height: innerHeight }, row: bounds('.channel-row'), category: bounds('.channel-category h2'), list: bounds('.nav-content'), dock: bounds('.voice-dock'), footer: bounds('.user-footer'),
      scrolls: [...document.querySelectorAll<HTMLElement>('.sidebar *')].filter(el => ['auto','scroll'].includes(getComputedStyle(el).overflowY) && el.scrollHeight > el.clientHeight + 1).map(el => el.className), horizontal: nav.scrollWidth > nav.clientWidth + 1, documentOverflow: document.documentElement.scrollWidth > innerWidth + 1 }
  })
}
for (const viewport of ux2026RequiredViewports) test(`inventory production navigation ${viewport.width}x${viewport.height}`, async ({ page }, info) => {
  const { width, height } = viewport
  const capture = width === 390 || width === 1440
  await page.setViewportSize(viewport); await open(page)
  if (capture) await page.screenshot({ path: info.outputPath('channels-top.png') })
  const before = await geometry(page)
  await page.locator('.channel-row').last().scrollIntoViewIfNeeded()
  if (capture) await page.screenshot({ path: info.outputPath('channels-bottom.png') })
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  await expect(page.locator('.direct-message-navigation > .channel-button')).toHaveCount(32)
  if (capture) await page.screenshot({ path: info.outputPath('direct-messages.png') })
  await writeFile(info.outputPath('geometry.json'), JSON.stringify(before, null, 2))
})
test('long names stay accessible without redundant channel tooltips', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  const category = page.locator('.channel-category-disclosure').first()
  const heading = await category.boundingBox(), panel = await page.locator('.nav-content').boundingBox()
  expect(heading!.x + heading!.width).toBeLessThanOrEqual(panel!.x + panel!.width)
  const channel = page.locator('.channel-row .channel-button').first()
  await channel.focus(); await expect(page.getByRole('tooltip')).toHaveCount(0)
  await expect(channel).toHaveAccessibleName(new RegExp(longName))
  await expect(channel).toHaveAccessibleName(/Непрочитанных сообщений: 120/)
  await expect(channel).toHaveAccessibleName(/Упоминаний: 3/)
  const memberCount = page.locator('.channel-member-count').first()
  await expect(memberCount).not.toHaveAttribute('title')
  await expect(memberCount).toHaveAttribute('aria-label', /^Участников в голосовом канале:/)
})
test('hovering a channel does not show a redundant tooltip', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  const trigger = page.locator('.channel-row .channel-button').first()
  await trigger.hover()
  await expect(page.getByRole('tooltip')).toHaveCount(0)
  const next = page.locator('.channel-row .channel-button').nth(1)
  await next.click()
  await expect(next).toHaveAttribute('aria-current', 'page')
})
test('channel destructive action is available through the ellipsis, not right-click', async ({ page }, info) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  const row = page.locator('.channel-row').first()
  await row.click({ button: 'right' })
  await expect(page.getByTestId('result')).toHaveText('')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.getByRole('menu')).toHaveCount(0)
  await page.screenshot({ path: info.outputPath('channel-right-click-no-dialog.png') })
  await row.getByRole('button', { name: 'Действия с каналом Обсуждение очень длинного названия канала для совместной работы 0' }).click()
  await expect(page.getByTestId('result')).toHaveText('action:channel-0-0')
})
test('one scroll surface, compact desktop rhythm and reachable final row above dock', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 480 }); await open(page)
  const g = await geometry(page)
  expect(g.scrolls).toEqual(['nav-content'])
  expect(g.horizontal).toBe(false); expect(g.documentOverflow).toBe(false)
  expect(g.row.height).toBeGreaterThanOrEqual(32); expect(g.row.height).toBeLessThanOrEqual(34)
  expect(g.category.height).toBeLessThanOrEqual(36)
  for (const channel of await page.locator('.channel-row .channel-button').all()) await channel.click()
  await expect(page.getByTestId('result')).toHaveText('channel-2-11')
  const last = await page.locator('.channel-row').last().boundingBox(), dock = await page.locator('.voice-dock').boundingBox()
  expect(last!.y + last!.height).toBeLessThanOrEqual(dock!.y + 1)
})
test.describe('touch', () => {
  test.use({ hasTouch: true, isMobile: true, viewport: { width: 390, height: 768 } })
  test('category and channel actions remain painted and hit-testable without hover', async ({ page }) => {
    await open(page)
    const action = page.locator('.channel-actions-button').first()
    expect(await action.evaluate(el => Number(getComputedStyle(el).opacity))).toBe(1)
    const box = await action.boundingBox(); expect(box!.width).toBeGreaterThanOrEqual(44); expect(box!.height).toBeGreaterThanOrEqual(44)
    await action.tap(); await expect(page.getByTestId('result')).toHaveText('action:channel-0-0')
    const g = await geometry(page); expect(g.horizontal).toBe(false); expect(g.scrolls).toEqual(['nav-content'])
  })
  test('large touch displays keep all navigation hit areas visible and at least 44px', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
    await page.locator('.sidebar').evaluate(el => el.classList.remove('is-open'))
    for (const selector of ['.channel-actions-button','.channel-favorite-toggle','.channel-category-disclosure','.sidebar-tabs button']) {
      const el = page.locator(selector).first(), r = await el.boundingBox()
      expect(r!.height).toBeGreaterThanOrEqual(44)
      expect(await el.evaluate(el => getComputedStyle(el).opacity)).toBe('1')
    }
  })

})
test('favorites, collapsed categories, selected states and DM survive navigation and reload', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  await page.locator('.channel-favorite-toggle').first().click()
  await expect(page.locator('.channel-favorites .channel-button')).toHaveCount(1)
  const favoriteChannel = page.locator('.channel-favorites .channel-button')
  await expect(favoriteChannel).toHaveAccessibleName(/Непрочитанных сообщений: 120/)
  await favoriteChannel.hover()
  await expect(page.getByRole('tooltip')).toHaveCount(0)
  await expect(page.locator('.channel-connected-mark').first()).toHaveAccessibleName('Подключено к голосу')
  const disclosure = page.locator('.channel-category-disclosure').first()
  await disclosure.click(); await expect(disclosure).toHaveAttribute('aria-expanded','false')
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  const dm = page.locator('.direct-message-navigation > .channel-button').last(); await dm.click(); await expect(dm).toHaveAttribute('aria-current','page')
  await page.getByRole('button', { name: 'Каналы', exact: true }).click()
  await expect(page.locator('.channel-category-disclosure').first()).toHaveAttribute('aria-expanded','false')
  await page.reload(); await expect(page.locator('.channel-favorites .channel-button')).toHaveCount(1)
  await expect(page.locator('.channel-category-disclosure').first()).toHaveAttribute('aria-expanded','false')
  await page.getByRole('searchbox', { name: 'Поиск каналов' }).fill('Канал 3.12')
  await expect(page.locator('.channel-row')).toHaveCount(1)
  await page.locator('.channel-row .channel-button').click(); await expect(page.getByTestId('result')).toHaveText('channel-2-11')
})
test('selected navigation controls use the accent color instead of a white marker', async ({ page }, info) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  const accent = await page.evaluate(() => {
    const probe = document.createElement('span')
    probe.style.color = getComputedStyle(document.documentElement).getPropertyValue('--gc-accent-text').trim()
    document.body.append(probe)
    const color = getComputedStyle(probe).color
    probe.remove()
    return color
  })
  const selectedTab = page.locator('.sidebar-tabs button[aria-pressed="true"]')
  expect(await markerColor(page, '.sidebar-tabs button[aria-pressed="true"]')).toBe(accent)
  expect(await markerColor(page, '.channel-navigation .channel-button.selected')).toBe(accent)
  await page.screenshot({ path: info.outputPath('selected-channel-marker.png') })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.screenshot({ path: info.outputPath('selected-channel-marker-mobile.png') })
  await page.setViewportSize({ width: 1440, height: 768 })
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  expect(await markerColor(page, '.sidebar-tabs button[aria-pressed="true"]')).toBe(accent)
  expect(await markerColor(page, '.direct-message-navigation > .channel-button.selected')).toBe(accent)
  await page.locator('.nav-content').evaluate(el => { el.scrollTop = 0 })
  await page.screenshot({ path: info.outputPath('selected-dm-marker.png') })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.locator('.nav-content').evaluate(el => { el.scrollTop = 0 })
  await page.screenshot({ path: info.outputPath('selected-dm-marker-mobile.png') })
  await selectedTab.focus()
  await expect(selectedTab).toBeFocused()
})
test('member ACL presentation and sidebar axe', async ({ page }) => {
  await open(page, true)
  await expect(page.locator('.channel-actions-button,.channel-category-actions button')).toHaveCount(0)
  await page.addScriptTag({ content: axe.source })
  const results = await page.evaluate(async () => (window as any).axe.run('.channel-navigation', { rules: {} }))
  expect(results.violations).toEqual([])
})

for (const viewport of [{ width: 320, height: 480 }, { width: 1024, height: 480 }, { width: 1440, height: 480 }]) test(`last channel remains painted above the dock at ${viewport.width}x${viewport.height}`, async ({ page }) => {
  await page.setViewportSize(viewport); await open(page)
  const last = page.locator('.channel-row .channel-button').last()
  await last.scrollIntoViewIfNeeded()
  const painted = await last.evaluate(el => { const r = el.getBoundingClientRect(); return el.contains(document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2)) })
  expect(painted).toBe(true)
  const g = await geometry(page); expect(g.list.bottom).toBeLessThanOrEqual(g.dock.y + 1)
  expect(g.scrolls).toEqual(['nav-content'])
  await last.click(); await expect(last).toHaveAttribute('aria-current','page')
})

test('keyboard selection, disclosure, favorites and contextual actions retain focus', async ({ page }, info) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  const first = page.locator('.channel-row .channel-button').first()
  await first.focus(); await first.press('Enter'); await expect(first).toHaveAttribute('aria-current','page')
  const favorite = page.locator('.channel-favorite-toggle').first()
  await favorite.focus(); await expect(favorite).toBeFocused(); expect(await favorite.evaluate(el => getComputedStyle(el).opacity)).toBe('1')
  await favorite.press('Space'); await expect(favorite).toHaveAttribute('aria-pressed','true')
  const category = page.locator('.channel-category-disclosure').first()
  await category.focus(); await expect(page.getByRole('tooltip')).toContainText('Длинное название раздела')
  await category.press('Enter'); await expect(category).toHaveAttribute('aria-expanded','false')
  await category.press('Space'); await expect(category).toHaveAttribute('aria-expanded','true')
  const action = page.locator('.channel-actions-button').first(); await action.focus()
  expect(await action.evaluate(el => getComputedStyle(el).opacity)).toBe('1')
  await action.press('Enter'); await expect(page.getByTestId('result')).toHaveText('action:channel-0-0')
  await page.getByRole('button', { name: 'Личные', exact: true }).press('Enter')
  const dm = page.locator('.direct-message-navigation > .channel-button').first()
  await dm.focus(); await expect(page.getByRole('tooltip')).toHaveText(longName)
  await dm.press('Enter'); await expect(dm).toHaveAttribute('aria-current','page')
  await page.screenshot({ path: info.outputPath('keyboard-full-name-hint.png') })
})
test('resize preserves selected navigation state at viewport edges and breakpoint boundaries', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 768 }); await open(page)
  await page.locator('.channel-favorite-toggle').first().click()
  await page.locator('.channel-category-disclosure').last().click()
  for (const viewport of [...ux2026EdgeViewports, ...ux2026BreakpointViewports]) {
    await page.setViewportSize(viewport)
    await expect(page.locator('.channel-favorites .channel-button')).toHaveAttribute('aria-current','page')
    await expect(page.locator('.channel-category-disclosure').last()).toHaveAttribute('aria-expanded','false')
    const g = await geometry(page); expect(g.horizontal).toBe(false); expect(g.scrolls).toEqual(['nav-content'])
  }
})

test('hiding the navigation ancestor removes its active category tooltip and releases the next control', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 768 }); await open(page)
  await page.locator('.channel-category-disclosure').first().hover()
  await expect(page.getByRole('tooltip')).toHaveCount(1)
  await page.locator('.sidebar').evaluate(el => el.classList.remove('is-open'))
  await expect(page.getByRole('tooltip')).toHaveCount(0)
  const trigger = page.getByRole('button', { name: 'Навигация', exact: true })
  await trigger.click(); await expect(trigger).toBeFocused()
})
for (const [width, height] of [[390,44],[1440,48]]) test(`ordinary DM row preserves ${height}px rhythm at ${width}px and grows for enlarged text`, async ({ page }) => {
  await page.setViewportSize({ width, height: 768 }); await open(page)
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  const row = page.locator('.direct-message-navigation > .channel-button').nth(1)
  expect((await row.boundingBox())!.height).toBe(height)
  await page.evaluate(() => document.documentElement.style.fontSize = '200%')
  const textFits = await row.evaluate(el => { const row = el.getBoundingClientRect(); const text = el.querySelector('.dm-identity')!.getBoundingClientRect(); return text.top >= row.top && text.bottom <= row.bottom })
  expect(textFits).toBe(true)
})
