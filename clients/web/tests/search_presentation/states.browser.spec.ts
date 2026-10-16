import { expect, test } from '@playwright/test'
import { api, message, channel } from './fixture_api'
for (const surface of ['search', 'files', 'dm-files']) test(`${surface} discards stale rows after a fresh ACL denial`, async ({ page }) => {
  await api(page)
  let denied = false
  await page.route(surface === 'search' ? '**/api/v1/search/messages?**' : `**/api/v1/${surface === 'dm-files' ? 'direct-messages' : 'channels'}/${channel}/messages*`, r => denied
    ? r.fulfill({ status: 403, json: { error: { code: 'FORBIDDEN' } } })
    : r.fulfill({ json: { messages: [surface === 'search' ? { ...message(1), kind: 'CHANNEL' } : surface === 'dm-files' ? { ...message(1), direct_message_id: channel } : message(1)], next_cursor: 'older' } }))
  await page.goto(`/tests/search_presentation/fixture.html?surface=${surface === 'dm-files' ? 'files&kind=dm' : surface}`)
  if (surface === 'search') {
    await page.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('orbit')
    await page.getByRole('button', { name: 'Найти', exact: true }).click()
    await expect(page.locator('.search-result')).toHaveCount(1)
  } else await expect(page.locator('.conversation-files tbody tr,.conversation-files .result-row')).toHaveCount(1)
  denied = true
  await page.getByRole('button', { name: surface === 'search' ? 'Показать ещё' : 'Показать более старые файлы', exact: true }).click()
  await expect(page.getByRole('alert')).toBeVisible()
  await expect(page.locator('.search-result,.conversation-files tbody tr,.conversation-files .result-row')).toHaveCount(0)
  await expect(page.getByRole('button', { name: /Показать (ещё|более старые файлы)/ })).toHaveCount(0)
})

test('files retry preserves the page for a transient failure and deduplicates later pages', async ({ page }, info) => {
  await api(page)
  let fail = true
  await page.route(`**/api/v1/channels/${channel}/messages*`, r => {
    const more = new URL(r.request().url()).searchParams.has('before')
    return more && fail ? r.fulfill({ status: 503, json: {} })
      : r.fulfill({ json: { messages: more ? [message(1), message(2)] : [message(1)], ...(more ? {} : { next_cursor: 'older' }) } })
  })
  await page.goto('/tests/search_presentation/fixture.html?surface=files')
  await expect(page.locator('.conversation-files tbody tr,.conversation-files .result-row')).toHaveCount(1)
  await page.getByRole('button', { name: 'Показать более старые файлы', exact: true }).click()
  await expect(page.getByRole('alert')).toBeVisible()
  await expect(page.locator('.conversation-files tbody tr,.conversation-files .result-row')).toHaveCount(1)
  await page.screenshot({ path: info.outputPath('files-retry.png') })
  fail = false; await page.getByRole('button', { name: 'Повторить', exact: true }).click()
  await expect(page.locator('.conversation-files tbody tr,.conversation-files .result-row')).toHaveCount(2)
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('an archive history page is cleared when access is revoked on pagination', async ({ page }) => {
  await api(page)
  await page.route(`**/api/v1/archives/text-channels/${channel}/messages*`, r => new URL(r.request().url()).searchParams.has('before')
    ? r.fulfill({ status: 403, json: { error: { code: 'FORBIDDEN' } } })
    : r.fulfill({ json: { messages: [message(1)], next_cursor: 'older' } }))
  await page.goto('/tests/search_presentation/fixture.html')
  await page.getByRole('button', { name: 'Архив', exact: true }).click()
  await page.getByRole('combobox', { name: 'Канал', exact: true }).selectOption(channel)
  await expect(page.locator('.archive-messages > li')).toHaveCount(1)
  await page.getByRole('button', { name: 'Показать ещё', exact: true }).click()
  await expect(page.getByRole('alert')).toBeVisible()
  await expect(page.locator('.archive-messages > li')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Показать ещё', exact: true })).toHaveCount(0)
})

test('denied archive catalog pagination removes prior channel names and the selected reader', async ({ page }) => {
  await api(page)
  await page.route('**/api/v1/archives/text-channels?**', r => r.fulfill({ status: 403, json: {} }))
  await page.route('**/api/v1/archives/text-channels', r => r.fulfill({ json: {
    channels: [{ id: channel, name: 'Synthetic archive', category_name: 'General', description: '', archived_at: '2026-10-12T10:00:00Z' }],
    revision: 1, can_manage: false, next_cursor: 'older',
  } }))
  await page.goto('/tests/search_presentation/fixture.html')
  await page.getByRole('button', { name: 'Архив', exact: true }).click()
  await page.getByRole('combobox', { name: 'Канал', exact: true }).selectOption(channel)
  await expect(page.locator('.archive-messages > li')).toHaveCount(2)
  await page.getByRole('button', { name: 'Ещё каналы', exact: true }).click()
  await expect(page.getByRole('alert')).toBeVisible()
  await expect(page.getByRole('combobox', { name: 'Канал', exact: true })).toHaveCount(0)
  await expect(page.getByRole('region', { name: 'История архивного канала' })).toHaveCount(0)
})
