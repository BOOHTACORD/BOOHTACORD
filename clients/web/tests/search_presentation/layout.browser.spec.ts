import { expect, test } from '@playwright/test'
import { expectAxeClear } from '../accessibility/axe'
import { api, channel, filename, id } from './fixture_api'
for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) for (const scale of [1, 2]) for (const surface of ['search', 'pins', 'archive', 'mentions', 'quick', 'files']) {
  test(`${surface} result layout at ${width}px / ${scale * 100}% text`, async ({ page }, info) => {
    await page.setViewportSize({ width, height: 1000 }); await api(page)
    await page.goto(`/tests/search_presentation/fixture.html?surface=${surface}`)
    await page.evaluate(scale => { document.documentElement.style.fontSize = `${scale * 16}px` }, scale)
    if (surface === 'search') {
      await page.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('orbit')
      await page.getByRole('button', { name: 'Найти', exact: true }).click()
      await expect(page.locator('.search-result')).toHaveCount(30)
    }
    for (const [mode, label] of [['pins', 'Закреплённые'], ['archive', 'Архив'], ['mentions', 'Упоминания']]) {
      if (surface === mode) await page.getByRole('group', { name: 'Поиск и упоминания' }).getByRole('button', { name: label, exact: true }).click()
    }
    if (surface === 'archive') await page.getByRole('combobox', { name: 'Канал', exact: true }).selectOption(channel)
    if (surface === 'pins') await expect(page.locator('.pin-panel ol > li')).toHaveCount(3)
    if (surface === 'mentions') await expect(page.locator('.mention-inbox .search-result')).toHaveCount(2)
    if (surface === 'archive') await expect(page.locator('.archive-messages > li')).toHaveCount(2)
    if (surface === 'quick') {
      await expect(page.getByRole('searchbox', { name: 'Найти канал или человека', exact: true })).toBeVisible()
      await expect(page.locator('.quick-jump-results > li')).toHaveCount(2)
      expect(await page.locator('.quick-jump-results').evaluate(el => getComputedStyle(el).listStyleType)).toBe('none')
      if (scale === 1) expect((await page.locator('.quick-jump-results > li').first().boundingBox())!.height).toBeLessThan(160)
    }
    if (surface === 'files') await expect(page.locator('.conversation-files tbody tr,.conversation-files .result-row')).toHaveCount(2)
    await page.evaluate(() => document.fonts.ready)
    await page.screenshot({ path: info.outputPath(`${surface}-layout.png`) })
    if (surface === 'quick' && width === 320 && scale === 2) {
      const placeholder = await page.locator('.quick-jump-panel input').evaluate(input => {
        const style = getComputedStyle(input)
        const context = document.createElement('canvas').getContext('2d')!
        context.font = `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`
        const text = input.getAttribute('placeholder') ?? ''
        const padding = Number.parseFloat(style.paddingLeft) + Number.parseFloat(style.paddingRight)
        return { textWidth: context.measureText(text).width, contentWidth: input.clientWidth - padding }
      })
      expect(placeholder.textWidth).toBeLessThanOrEqual(placeholder.contentWidth)
    }
    if (surface === 'search') {
      const avatar = page.locator('.search-result-avatar').first()
      expect(await avatar.evaluate(el => el.scrollHeight - el.clientHeight)).toBeLessThanOrEqual(1)
      expect(await avatar.evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
    }
    if (surface === 'files') {
      await expect(page.getByRole('list', { name: 'Файлы беседы', exact: true }).getByRole('listitem')).toHaveCount(2)
      await expect(page.getByRole('table')).toHaveCount(0)
      const full = page.locator('.conversation-files details').first()
      await full.locator('summary').focus(); await page.keyboard.press('Enter')
      await expect(full.locator('p')).toHaveText(filename)
      await full.locator('summary').click()
    }
    await expect(page.locator('.result-row').first()).toBeVisible()
    if (['pins', 'archive', 'mentions'].includes(surface)) await expect(page.getByRole('heading')).toHaveCount(1)
    const rail = page.locator('.search-aside')
    expect(await rail.evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
    for (const owner of await page.locator('#search-mode-content,.conversation-files,.quick-jump-results').all()) {
      expect(await owner.evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
    }
    for (const el of await page.locator('.result-row').all()) expect(await el.evaluate(el => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
    const action = page.locator('.result-row button').first()
    if (await action.count()) {
      await action.focus(); await expect(action).toBeInViewport()
      const box = (await action.boundingBox())!; expect(box.height).toBeGreaterThanOrEqual(44)
    }
    await page.evaluate(() => document.fonts.ready)
    await page.screenshot({ path: info.outputPath(`${surface}.png`) })
    await expectAxeClear(page)
    if (surface === 'files') {
      await page.getByRole('button', { name: `Перейти к сообщению с файлом ${filename}`, exact: true }).first().click()
      await expect(page.getByTestId('action')).toHaveText(id(1))
    }
  })
}
