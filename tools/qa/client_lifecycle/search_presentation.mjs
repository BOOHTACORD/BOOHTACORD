import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { api, channel, expect, openNavigation, status } from './request.mjs'

// Owned synthetic guild only: existing production upload/history/search routes.
export async function searchPresentation(page, admin, fixture, input, report) {
  const touch = input.viewport.has_touch
  const activate = element => touch ? element.tap() : element.click()
  async function search() {
    await openNavigation(page)
    await page.locator('.guild-search-button').click()
    await expect(page.getByTestId('search-panel')).toBeVisible()
  }
  async function returned(expected) {
    const context = page.getByTestId('search-message-context')
    await expect(context.locator('[data-search-anchor]')).toBeFocused()
    if (expected) await expect(context.locator('[data-search-anchor]')).toHaveAttribute('data-message-id', expected)
    await activate(context.getByRole('button', { name: 'Вернуться к исходной позиции', exact: true }))
    await expect(context).not.toBeVisible()
    await expect(page.getByRole('heading', { name: 'Text', exact: true })).toBeVisible()
  }
  await channel(page, 'Text')
  if (await page.getByRole('button', { name: 'Закрыть навигацию', exact: true }).isVisible()) await page.getByRole('button', { name: 'Закрыть навигацию', exact: true }).click()
  const draft = page.getByRole('textbox', { name: 'Сообщение', exact: true })
  await expect(draft).toBeVisible()
  await draft.fill('Synthetic compact unsent draft')
  const file = 'Synthetic-compact-results-long-filename-for-keyboard-and-touch.txt'
  // Prepare data through the real server; pending upload-queue layout is its own gate.
  const uploaded = await page.evaluate(async ({ channelId, file }) => {
    const form = new FormData()
    form.append('file', new File(['Owned synthetic compact results fixture.'], file, { type: 'text/plain' }))
    const response = await fetch(`/api/v1/channels/${channelId}/attachments`, { method: 'POST', body: form, credentials: 'same-origin' })
    return { status: response.status, body: await response.json() }
  }, { channelId: fixture.channelId, file })
  status(uploaded, 201)
  const published = await api(page, `/channels/${fixture.channelId}/messages`, 'POST', {
    client_message_id: randomUUID(), body: 'Synthetic compact panel attachment', attachment_ids: [uploaded.body.id],
  }); status(published, 201)
  await page.locator('.text-conversation .conversation-overflow__trigger').click()
  await page.getByRole('menuitem', { name: 'Файлы беседы', exact: true }).click()
  const files = page.locator('.conversation-files')
  await expect(files.getByRole('listitem')).toHaveCount(1)
  await activate(files.locator('.file-name-detail summary'))
  await expect(files.locator('.file-name-detail p')).toHaveText(file)
  await page.screenshot({ path: input.directory + '/compact-files.png' })
  await activate(files.getByRole('button', { name: `Перейти к сообщению с файлом ${file}`, exact: true }))
  await returned(published.body.id)
  await expect(draft).toHaveValue('Synthetic compact unsent draft')

  let pinId
  for (let index = 0; index < 4; index++) { const posted = await api(page, `/channels/${fixture.channelId}/messages`, 'POST', {
    client_message_id: randomUUID(), body: (index === 3 ? 'Unrelated '.repeat(70) : '') + `Synthetic compact navigation sample ${index}`,
  }); status(posted, 201); pinId ??= posted.body.id }
  await search()
  const panel = page.getByTestId('search-panel'), owner = panel.locator('#search-mode-content')
  const query = panel.getByRole('searchbox', { name: 'Запрос', exact: true })
  await query.fill('Synthetic navigation')
  await panel.getByLabel('Область поиска').selectOption('current')
  const disclosure = panel.locator('.search-filter-disclosure > summary')
  await activate(disclosure)
  await panel.getByLabel('Вложения', { exact: true }).selectOption('without')
  await panel.getByLabel('С даты', { exact: true }).fill('2026-01-01')
  await activate(disclosure)
  const response = page.waitForResponse(response => new URL(response.url()).pathname === '/api/v1/search/messages' && response.request().method() === 'GET')
  await activate(panel.getByRole('button', { name: 'Найти', exact: true }))
  const searchResult = await (await response).json()
  await expect.poll(() => panel.locator('.search-result').count()).toBeGreaterThanOrEqual(4)
  const excerpt = panel.locator('.search-result-body').first()
  await expect(excerpt.locator('mark')).toHaveText(['Synthetic', 'navigation'])
  assert.ok((await excerpt.innerText()).startsWith('…'), 'A multiword full-text hit must expose its late context')
  await owner.evaluate(el => { el.scrollTop = Math.min(80, el.scrollHeight - el.clientHeight); el.dispatchEvent(new Event('scroll')) })
  const open = panel.getByRole('button', { name: /Открыть сообщение от/ }).first()
  await open.focus(); await open.scrollIntoViewIfNeeded()
  const before = await owner.evaluate(el => el.scrollTop)
  assert.ok(before > 0, 'Search return must exercise a nonzero result position')
  await page.screenshot({ path: input.directory + '/compact-search-filters.png' })
  await activate(open)
  await returned(searchResult.messages[0].id)
  await search()
  await expect(query).toHaveValue('Synthetic navigation')
  await expect(panel.getByLabel('Область поиска')).toHaveValue('current')
  await expect(panel.getByLabel('Вложения', { exact: true })).toHaveValue('without')
  await expect(panel.getByLabel('С даты', { exact: true })).toHaveValue('2026-01-01')
  await expect.poll(() => owner.evaluate(el => el.scrollTop)).toBe(before)
  await page.screenshot({ path: input.directory + '/compact-search-return.png' })
  await activate(panel.getByRole('button', { name: 'Закрыть поиск', exact: true }))
  await expect(panel).not.toBeVisible()

  status(await api(admin, `/admin/text-channels/${fixture.channelId}/pins/${pinId}`, 'PUT'), 204)
  await search()
  await activate(panel.getByRole('button', { name: 'Закреплённые', exact: true }))
  await expect(panel.locator('.pin-panel .result-row')).toHaveCount(1)
  await page.screenshot({ path: input.directory + '/compact-pins.png' })
  await activate(panel.getByRole('button', { name: /Открыть закреплённое сообщение/ }))
  await returned(pinId)
  await search()
  await activate(panel.getByRole('button', { name: 'Упоминания', exact: true }))
  const mentions = await api(page, '/mentions'); status(mentions, 200)
  const mention = panel.getByRole('button', { name: /Перейти к упоминанию от/ }).first()
  await expect(mention).toBeVisible()
  await page.screenshot({ path: input.directory + '/compact-mentions.png' })
  await activate(mention)
  await returned(mentions.body.mentions[0].message_id)

  const topology = await api(admin, '/channels'); status(topology, 200)
  const category = topology.body.categories.find(item => item.channels.some(item => item.id === fixture.channelId))
  assert.ok(category)
  const archived = await api(admin, `/admin/categories/${category.id}/channels`, 'POST', { name: 'CompactArchive', kind: 'TEXT' }); status(archived, 201)
  status(await api(admin, `/channels/${archived.body.id}/messages`, 'POST', { client_message_id: randomUUID(), body: 'Synthetic archived detail' }), 201)
  const archives = await api(admin, '/archives/text-channels'); status(archives, 200)
  status(await api(admin, `/admin/text-channels/${archived.body.id}/readonly-archive`, 'POST', { expected_revision: archives.body.revision, confirm: true }), 200)
  await search()
  await activate(panel.getByRole('button', { name: 'Архив', exact: true }))
  await panel.getByRole('combobox', { name: 'Канал', exact: true }).selectOption(archived.body.id)
  await expect(panel.getByRole('region', { name: 'История архивного канала' })).toContainText('Synthetic archived detail')
  await page.screenshot({ path: input.directory + '/compact-archive.png' })
  await activate(panel.getByRole('button', { name: 'Закрыть поиск', exact: true }))
  await expect(panel).not.toBeVisible()
  await search()
  await page.getByRole('group', { name: 'Тип поиска' }).getByRole('button', { name: 'Каналы и люди', exact: true }).click()
  const quick = page.getByTestId('quick-jump-panel')
  await quick.getByRole('searchbox', { name: 'Найти канал или человека', exact: true }).fill('log')
  await page.screenshot({ path: input.directory + '/compact-quick-jump.png' })
  await activate(quick.getByRole('button', { name: '#log Текстовый канал', exact: true }))
  await expect(quick).not.toBeVisible()
  await expect(page.locator('.drawer-scrim')).not.toBeVisible()
  await expect(page.getByRole('heading', { name: 'log', exact: true })).toBeVisible()
  assert.equal(new URL(page.url()).hash, `#workspace/channel/${fixture.logChannelId}`)
  await channel(page, 'Text')
  await expect(page.getByRole('heading', { name: 'Text', exact: true })).toBeVisible()
  await expect(draft).toHaveValue('Synthetic compact unsent draft')
  await draft.fill('')
  report.search_presentation = { six_surfaces: true, actual_api: true, multiword_late_preview: true, upload_file_context: true, draft_retained: true,
    filter_message_return: true, nonzero_result_scroll_restored: true, query_and_filters_restored: true,
    pinned_and_mention_context: true, archive_reader: true, quick_jump: true, touch }
}
