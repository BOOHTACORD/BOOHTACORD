import { expect, test } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { begin, cacheHas, cacheSize, newer, older, scrollToRow, setup } from './history_edit_helpers'
import { uid } from './history_edit_data'

test('history edit diagnostic two simultaneous editors preserve both unsaved values on ordinary scroll', async ({ page }) => {
  await setup(page)
  await (await begin(page)).fill('First unsaved fixture')
  await page.locator(`[data-message-id="${uid(1999)}"] textarea`).evaluate((element) => {
    const input = element as HTMLTextAreaElement; input.setSelectionRange(2, 7)
  })
  const second = page.locator(`[data-message-id="${uid(1998)}"]`)
  await second.hover(); await second.getByRole('button', { name: 'Изменить', exact: true }).click()
  const firstInput = page.locator(`[data-message-id="${uid(1999)}"] textarea`)
  const secondInput = second.locator('textarea')
  await secondInput.fill('Second unsaved fixture')
  await secondInput.evaluate((element) => { const input = element as HTMLTextAreaElement
    input.setSelectionRange(1, 5); Object.assign(window, { originalSecondEditor: input }) })
  await expect(firstInput).toHaveValue('First unsaved fixture')
  await expect(secondInput).toHaveValue('Second unsaved fixture')
  await expect(firstInput.locator('..').getByRole('button', { name: /^Убрать упоминание / })).toHaveCount(1)
  await expect(secondInput.locator('..').getByRole('button', { name: /^Убрать упоминание / })).toHaveCount(1)
  const before = { first: await firstInput.inputValue(), second: await secondInput.inputValue() }
  await page.getByRole('log', { name: 'История сообщений' }).evaluate((element) => {
    element.scrollTop = 0; element.dispatchEvent(new Event('scroll'))
  })
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  const result = { scope: 'production component fixture only; no actual AppShell/API claim', before,
    after: { firstEditorCount: await firstInput.count(), secondEditorCount: await secondInput.count(),
      cacheSize: await cacheSize(page), firstMessageStillCached: await cacheHas(page, 999),
      secondMessageStillCached: await cacheHas(page, 998) }, afterReturn: { firstEditorCount: -1, secondEditorCount: -1 } }
  await scrollToRow(page, 999)
  result.afterReturn = { firstEditorCount: await firstInput.count(), secondEditorCount: await secondInput.count() }
  await writeFile(test.info().outputPath('diagnostic.json'), JSON.stringify(result, null, 2))
  await expect(firstInput).toHaveValue('First unsaved fixture')
  await expect(secondInput).toHaveValue('Second unsaved fixture')
  await expect(firstInput.locator('..').getByRole('button', { name: /^Убрать упоминание / })).toHaveCount(1)
  await expect(secondInput.locator('..').getByRole('button', { name: /^Убрать упоминание / })).toHaveCount(1)
  expect(await firstInput.evaluate((element) => [(element as HTMLTextAreaElement).selectionStart, (element as HTMLTextAreaElement).selectionEnd])).toEqual([2, 7])
  await older(page); for (let i = 0; i < 3; i++) await newer(page)
  await expect(firstInput).toHaveValue('First unsaved fixture')
  await expect(secondInput).toHaveValue('Second unsaved fixture')
  expect(await secondInput.evaluate((element) => element === (window as any).originalSecondEditor)).toBe(true)
  expect(await secondInput.evaluate((element) => [(element as HTMLTextAreaElement).selectionStart, (element as HTMLTextAreaElement).selectionEnd])).toEqual([1, 5])
  await expect.poll(() => cacheSize(page)).toBe(500)
})
