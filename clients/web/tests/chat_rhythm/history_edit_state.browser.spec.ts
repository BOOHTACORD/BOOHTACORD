import { expect, test } from '@playwright/test'
import { begin, editor, older, roundtrip, setup } from './history_edit_helpers'
import { peer } from './history_edit_data'

test('history edit conflict preserves text mentions and revision through eviction', async ({ page }) => {
  const { state, requests } = await setup(page); state.conflict = true
  const input = await begin(page); await input.fill('Conflict fixture draft')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('Обновите версию')
  await roundtrip(page)
  await expect(input).toHaveValue('Conflict fixture draft')
  await expect(page.getByRole('button', { name: 'Сохранить', exact: true })).toBeDisabled()
  await expect(page.getByRole('button', { name: /^Убрать упоминание / })).toHaveCount(1)
  state.revision = 2
  await page.getByRole('button', { name: 'Обновить версию', exact: true }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Версия обновлена' })).toHaveCount(1)
  await expect(input).toHaveValue('Conflict fixture draft')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(input).toHaveCount(0)
  expect(requests.map(({ body }) => body)).toEqual([
    { body: 'Conflict fixture draft', expected_revision: 1, mention_user_ids: [peer] },
    { body: 'Conflict fixture draft', expected_revision: 2, mention_user_ids: [peer] },
  ])
})

test('history edit deleted refresh keeps the existing draft-for-copy notice', async ({ page }) => {
  const { state } = await setup(page); state.conflict = true
  const input = await begin(page); await input.fill('Draft for copying')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Обновить версию', exact: true })).toHaveCount(1)
  await roundtrip(page); state.deleted = true; state.revision = 2
  await page.getByRole('button', { name: 'Обновить версию', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('черновик сохранён для копирования')
  await expect(input).toHaveValue('Draft for copying')
  await expect(page.getByRole('button', { name: 'Сохранить', exact: true })).toBeDisabled()
})

test('history edit pending request remains duplicate guarded through eviction and return', async ({ page }) => {
  const { state, requests } = await setup(page)
  let release!: () => void; state.pending = new Promise<void>((resolve) => { release = resolve })
  const input = await begin(page); await input.fill('Pending draft')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(input).toBeDisabled()
  await roundtrip(page)
  await expect(input).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Обрабатываем…', exact: true })).toBeDisabled()
  const stablePager = page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })
  await stablePager.focus(); await expect(stablePager).toBeFocused()
  expect(requests).toHaveLength(1); release()
  await expect(input).toHaveCount(0); expect(requests).toHaveLength(1)
  await expect(stablePager).toBeFocused()
})

for (const key of ['Escape', 'Control+Enter']) test(`history edit detached ${key} closes only its editor and restores history focus`, async ({ page }) => {
  const { requests } = await setup(page)
  const input = await begin(page); await input.fill('Detached command draft'); await older(page)
  await expect(input).toHaveCount(1)
  await input.evaluate((element) => (element as HTMLElement).focus({ preventScroll: true }))
  await page.keyboard.press(key)
  await expect(editor(page)).toHaveCount(0)
  expect(await page.getByRole('log', { name: 'История сообщений' }).evaluate((element) => element.contains(document.activeElement))).toBe(true)
  expect(requests).toHaveLength(key === 'Escape' ? 0 : 1)
  if (key !== 'Escape') expect(requests[0]?.body).toEqual({ body: 'Detached command draft', expected_revision: 1, mention_user_ids: [peer] })
})
