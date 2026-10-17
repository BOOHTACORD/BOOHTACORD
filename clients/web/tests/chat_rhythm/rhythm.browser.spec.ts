import { test, expect } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { kinds, row, mount, metrics, expectWithinViewport } from './helpers'
import { uid } from './data'
import { expectAxeClear } from '../accessibility/axe'

for (const kind of kinds) for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) {
  test(`inventory ${kind} ${width}px`, async ({ page }, info) => {
    await page.setViewportSize({ width, height: 900 })
    await mount(page, kind)
    const data = await metrics(page)
    await expectWithinViewport(page)
    await page.screenshot({ path: info.outputPath('history-top.png') })
    await row(page, 5).scrollIntoViewIfNeeded()
    await expect(row(page, 5).locator('.attachment-card')).toHaveCount(2)
    await expectWithinViewport(page)
    await page.screenshot({ path: info.outputPath('attachments.png') })
    await row(page, 11).scrollIntoViewIfNeeded()
    await expect(row(page, 11).locator('pre code')).toBeVisible()
    const code = row(page, 11).getByRole('region', { name: 'Код сообщения' })
    await code.focus()
    await code.press('ArrowRight')
    await expect(code).toBeFocused()
    await expectWithinViewport(page)
    await page.screenshot({ path: info.outputPath('rich-text.png') })
    await writeFile(info.outputPath('geometry.json'), JSON.stringify(data, null, 2))
  })
}
for (const kind of kinds) {
  test(`continuous ${kind} preserves grouping and visible full timestamps`, async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await mount(page, kind)
    await expect(row(page, 2)).toHaveClass(/grouped-message/)
    await expect(row(page, 4)).not.toHaveClass(/grouped-message/)
    for (const n of (kind === 'CHANNEL' ? [7, 9, 10, 11, 12] : [7, 9, 10, 12])) await expect(row(page, n)).not.toHaveClass(/grouped-message/)
    await expect(page.locator('.history-date')).toHaveCount(2)
    const g = await metrics(page)
    expect(g.rows.find(r => r.id === uid(2))!.gap).toBe(4)
    expect(g.rows.find(r => r.id === uid(4))!.gap).toBe(12)
    for (const n of [1, 2, 8, 9, 10]) {
      const time = row(page, n).locator('time').first()
      await expect(time).toHaveAttribute('datetime', /2026-10-15T/)
      await expect(time).toHaveAttribute('aria-label', /2026.*10:/)
      expect(await time.evaluate(el => !el.closest('.gc-sr-only,[aria-hidden="true"]'))).toBe(true)
    }
    await expect(row(page, 9)).toContainText('Сообщение удалено')
    await expect(row(page, 8)).toContainText('изменено')
    await expectAxeClear(page, '.message-list')
  })
  test(`empty ${kind} reaction palette is keyboard accessible and preserves focus/counts`, async ({ page }, info) => {
    const commands = await mount(page, kind)
    const tools = row(page, 1).getByRole('group', { name: 'Реакции на сообщение', exact: true })
    const picker = tools.locator('details'), summary = picker.locator('summary')
    await expect(picker).not.toHaveAttribute('open')
    await expect(picker.getByRole('button')).toHaveCount(0)
    await summary.focus(); await summary.press('Enter')
    await page.screenshot({ path: info.outputPath('reaction-palette-focus.png') })
    await expect(picker.getByRole('button', { name: /^Реакция / })).toHaveCount(6)
    const like = picker.getByRole('button', { name: 'Реакция 👍', exact: true })
    await like.click()
    await expect(like).toBeFocused()
    await expect(tools.locator('.reaction-counts').getByRole('button', { name: 'Реакция 👍', exact: true })).toHaveAttribute('aria-pressed', 'true')
    await summary.press('Enter')
    await expect(picker).not.toHaveAttribute('open')
    const count = tools.locator('.reaction-counts').getByRole('button', { name: 'Реакция 👍', exact: true })
    await expect(count).toBeVisible()
    await page.screenshot({ path: info.outputPath('reaction-count-closed.png') })
    await count.click()
    await expect(tools.locator('.reaction-counts')).toHaveCount(0)
    expect(commands.filter(c => c.path.includes('/reactions/')).map(c => c.method)).toEqual(['PUT', 'DELETE'])
  })
}

for (const kind of kinds) test(`${kind} image viewer and private download links remain bounded`, async ({ page }, info) => {
  await page.setViewportSize({ width: 390, height: 900 })
  await mount(page, kind)
  const message = row(page, 5), open = message.getByRole('button', { name: 'Открыть изображение Изображение.png' })
  const downloads = message.getByRole('link', { name: /^Скачать / })
  await expect(downloads).toHaveCount(2)
  for (const link of await downloads.all()) await expect(link).toHaveAttribute('href', kind === 'CHANNEL' ? /\/channels\// : /\/direct-messages\//)
  await open.click()
  const viewer = page.getByRole('dialog', { name: 'Просмотр изображения Изображение.png' })
  await expect(viewer.getByRole('img')).toBeVisible()
  const rect = (await viewer.boundingBox())!
  expect(rect.x).toBeGreaterThanOrEqual(0)
  expect(rect.x + rect.width).toBeLessThanOrEqual(390)
  await page.screenshot({ path: info.outputPath('image-viewer.png') })
  await page.keyboard.press('Escape')
  await expect(viewer).not.toBeVisible()
  await expect(open).toBeFocused()
})
