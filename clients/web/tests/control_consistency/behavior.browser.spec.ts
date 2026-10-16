import { expect, test } from '@playwright/test'
import { fixtureRoutes, id } from './routes'

test.use({ channel: 'chromium' })

test('native guild select, save pending/disabled and failure preserve the form', async ({ page }) => {
  await fixtureRoutes(page)
  let release!: () => void, writes = 0, payload: unknown
  let fail = false
  await page.route('**/api/v1/admin/guild-settings', async route => {
    if (route.request().method() === 'GET') return route.fulfill({ json: { name: 'Тестовая гильдия', revision: 1, welcome_channel_id: null } })
    writes++; payload = route.request().postDataJSON()
    if (!fail) await new Promise<void>(resolve => { release = resolve })
    return route.fulfill({ status: fail ? 503 : 200, json: fail ? {} : { name: 'Гильдия после правки', revision: 2, welcome_channel_id: id } })
  })
  await page.goto('/tests/control_consistency/fixture.html?surface=guild')
  const name = page.getByLabel('Название гильдии', { exact: true })
  await expect(name).toBeEnabled(); await name.fill('Гильдия после правки')
  const select = page.getByLabel('Приветствия новых участников')
  await expect(select).toBeEnabled()
  await select.focus(); await select.press('#')
  await expect(select).toHaveValue(id)
  const save = page.getByRole('button', { name: 'Сохранить', exact: true })
  await save.click()
  const busy = page.getByRole('button', { name: 'Сохраняем…' })
  await expect(busy).toBeDisabled(); await expect(busy).toHaveAttribute('aria-busy', 'true')
  await expect(name).toBeDisabled()
  const bounds = await busy.boundingBox()
  await page.mouse.click(bounds!.x + bounds!.width / 2, bounds!.y + bounds!.height / 2)
  expect(writes).toBe(1)
  expect(payload).toEqual({ name: 'Гильдия после правки', welcome_channel_id: id, expected_revision: 1 })
  release(); await expect(page.locator('.guild-settings').getByRole('status')).toContainText('сохранены')
  fail = true; await name.fill('Несохранённая правка'); await save.click()
  await expect(page.getByRole('alert')).toContainText('503')
  await expect(name).toHaveValue('Несохранённая правка')
  await expect(select).toHaveValue(id)
})

test('files Load more disables only the pending operation and retains Open/Close', async ({ page }) => {
  await fixtureRoutes(page)
  let release!: () => void, reads = 0
  await page.route(`**/api/v1/channels/${id}/messages?before=older`, async route => {
    reads++; await new Promise<void>(resolve => { release = resolve })
    return route.fulfill({ json: { messages: [{
      id: 'older-message', channel_id: id, author_id: 'author', client_message_id: 'older-client',
      body: '', created_at: '2026-10-14T12:00:00Z', revision: 1, deleted: false, mention_user_ids: [],
      attachments: [{ id: 'older-file', original_name: 'План.pdf', byte_size: 1024 }],
    }] } })
  })
  await page.goto('/tests/control_consistency/fixture.html?surface=files')
  await expect(page.locator('.conversation-files .result-row')).toHaveCount(1)
  await page.getByRole('button', { name: 'Показать более старые файлы' }).click()
  const busy = page.getByRole('button', { name: 'Загружаем…' })
  await expect(busy).toBeDisabled(); await expect(busy).toHaveAttribute('aria-busy', 'true')
  await page.getByRole('button', { name: /^Перейти к сообщению с файлом/ }).press('Enter')
  await expect(page.getByTestId('action')).toHaveText('open')
  expect(reads).toBe(1)
  release(); await expect(page.locator('.conversation-files .result-row')).toHaveCount(2)
  await page.getByRole('button', { name: 'Закрыть', exact: true }).press('Enter')
  await expect(page.getByTestId('action')).toHaveText('close')
})
