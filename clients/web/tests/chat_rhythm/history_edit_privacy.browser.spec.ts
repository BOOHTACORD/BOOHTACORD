import { expect, test } from '@playwright/test'
import { begin, capture, editor, newer, older, setup } from './history_edit_helpers'
import { channelA, channelB } from './history_edit_data'

test('history edit full500-state registry shows visible feedback without rendering500 rows', async ({ page }) => {
  await setup(page, 500, 1440, true)
  await expect(page.locator('.message-item')).toHaveCount(1)
  await page.locator('.message-item').hover()
  await page.getByRole('button', { name: 'Изменить', exact: true }).click()
  await expect(editor(page)).toHaveCount(0)
  await expect(page.getByRole('status')).toHaveText('Сначала сохраните или отмените одно из открытых редактирований.')
  expect(await page.evaluate(() => (window as any).historyEditFixture.capacitySize())).toBe(500)
  await capture(page, 'capacity-feedback-1440')
})

test('history edit detached controls leave Tab order and restore original tabindex on return', async ({ page }) => {
  await setup(page); const input = await begin(page)
  await input.evaluate((element) => Object.assign(window, { originalTabStops:
    [...element.closest('[data-message-id]')!.querySelectorAll<HTMLElement>('button, textarea, [tabindex], summary')]
      .map((target) => [target, target.getAttribute('tabindex')]) }))
  await older(page)
  await expect(input).toHaveCount(1)
  expect(await input.evaluate((element) => [...element.closest('[data-message-id], [data-retained-message-id]')!.querySelectorAll<HTMLElement>('button, textarea, [tabindex], summary')]
    .every((target) => target.tabIndex === -1))).toBe(true)
  await input.evaluate((element) => (element as HTMLElement).focus({ preventScroll: true }))
  await expect(input).toBeFocused()
  for (const key of ['Tab', 'Shift+Tab']) {
    await page.keyboard.press(key)
    expect(await page.evaluate(() => getComputedStyle(document.activeElement!.closest('[data-message-id]') ?? document.body).clipPath)).not.toBe('inset(50%)')
  }
  for (let i = 0; i < 3; i++) await newer(page)
  expect(await page.evaluate(() => (window as any).originalTabStops.every(([element, value]: [HTMLElement, string | null]) => element.getAttribute('tabindex') === value))).toBe(true)
})

for (const detached of [false, true]) for (const trigger of [
  'Switch account', 'Switch channel', 'Reset store', 'Empty store', 'Clear draft memory', 'Clear authenticated state',
]) test(`history edit privacy ${trigger} clears ${detached ? 'detached' : 'visible'} editor`, async ({ page }) => {
  await setup(page); const input = await begin(page)
  await input.fill('Private unsaved fixture')
  if (detached) { await older(page); await expect(input).toHaveCount(1) }
  await page.getByRole('button', { name: trigger, exact: true }).click()
  await expect(editor(page)).toHaveCount(0)
  if (trigger.startsWith('Switch')) await page.getByRole('button', { name: trigger, exact: true }).click()
  else if (trigger.includes('store')) await page.getByRole('button', { name: 'Reload history', exact: true }).click()
  else await page.getByRole('button', { name: 'Remount same account', exact: true }).click()
  await expect(editor(page)).toHaveCount(0)
  expect(await page.locator('textarea').evaluateAll((elements) => elements.some((element) => element.value === 'Private unsaved fixture'))).toBe(false)
})

test('history edit auth clear cannot resurrect composer drafts from old callbacks or unmount', async ({ page }) => {
  await setup(page)
  const composer = page.getByRole('textbox', { name: 'Fixture composer', exact: true })
  await composer.fill('Channel A draft')
  await page.getByRole('button', { name: 'Switch channel', exact: true }).click()
  await expect(composer).toHaveValue('')
  await composer.fill('Channel B draft')
  await page.getByRole('button', { name: 'Switch channel', exact: true }).click()
  await expect(composer).toHaveValue('Channel A draft')
  expect(await page.evaluate((id) => (window as any).historyEditFixture.remembered(id)?.body, channelB)).toBe('Channel B draft')
  await page.getByRole('button', { name: 'Clear draft memory', exact: true }).click()
  await page.getByRole('button', { name: 'Late composer callback', exact: true }).click()
  await expect(composer).toHaveCount(0)
  for (const id of [channelA, channelB])
    expect(await page.evaluate((key) => (window as any).historyEditFixture.remembered(key), id)).toBeNull()
})
