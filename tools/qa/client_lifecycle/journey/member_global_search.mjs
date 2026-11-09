import assert from 'node:assert/strict'
import { expect, openNavigation } from '../request.mjs'

export async function memberGlobalSearch(guest, input, report) {
  await openNavigation(guest)
  await guest.locator('.guild-search-button').click()
  const globalSearch = guest.getByTestId('search-panel')
  await expect(globalSearch).toBeVisible()
  await expect(globalSearch.getByRole('heading', { name: 'Поиск сообщений', exact: true })).toBeVisible()
  await expect(globalSearch.getByLabel('Область поиска')).toHaveValue('all')
  await expect(globalSearch.getByLabel('Автор')).toHaveValue('')
  await expect(globalSearch.getByLabel('Вложения')).toHaveValue('any')
  await globalSearch.locator('.search-filter-disclosure > summary').click()
  await expect(globalSearch.getByLabel('С даты')).toBeVisible()
  await expect(globalSearch.getByLabel('По дату включительно')).toBeVisible()
  await globalSearch.getByRole('searchbox', { name: 'Запрос', exact: true }).fill('')
  await expect(globalSearch.getByRole('button', { name: 'Найти', exact: true })).toBeDisabled()
  await guest.screenshot({ path: input.directory+'/global-search.png' })
  await globalSearch.getByRole('searchbox', { name: 'Запрос' }).fill('Synthetic UIUX channel sample readable conversation text')
  const globalResponse = guest.waitForResponse(r => r.request().method()==='GET' && new URL(r.url()).pathname==='/api/v1/search/messages')
  await globalSearch.getByRole('button', { name: 'Найти', exact: true }).click()
  const globalBody = await (await globalResponse).json()
  const globalResults = globalSearch.locator('.search-result')
  await expect(globalResults.first()).toBeVisible()
  const globalMessage = globalBody.messages.find(message => message.body === 'Synthetic UIUX channel sample: readable conversation text.')
  assert.ok(globalMessage, 'The global search result must resolve to its server message')
  await globalResults.filter({ hasText:globalMessage.body }).getByRole('button').click()
  const globalTarget = guest.locator(`.text-conversation .message-list [data-message-id="${globalMessage.id}"].message-search-target`)
  await expect(globalTarget).toContainText('Synthetic UIUX channel sample')
  await expect(guest.getByTestId('search-message-context')).toHaveCount(0)
  await expect(guest.getByTestId('search-aside-panel')).toBeHidden()
  await expect.poll(() => globalTarget.evaluate(row => {
    const viewport = row.closest('.message-list')
    const bounds = row.getBoundingClientRect(), view = viewport.getBoundingClientRect()
    return bounds.top >= view.top && bounds.bottom <= view.bottom
  })).toBe(true)
  await guest.screenshot({ path: input.directory+'/global-search-result-in-conversation.png' })
  console.log('stage=qa-member-global-search-complete')
  report.global_search_full_app = {
    panel: true,
    defaultGlobalScope: true,
    authorAttachmentDateFilters: true,
    disposableApiResults: true,
    resultScrollsIntoConversation: true,
    flashHighlight: true,
    searchContextViewRemoved: true,
  }
}
