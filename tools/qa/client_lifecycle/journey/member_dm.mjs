import assert from 'node:assert/strict'
import { expect, openNavigation } from '../request.mjs'
import { conversationHeaders } from '../header_actions.mjs'

export async function memberDM(guest, input, report) {
  if (input.viewport.is_mobile) {
    const sidebar = guest.locator('.sidebar')
    await guest.getByRole('button', { name: 'Открыть навигацию', exact: true }).click()
    await expect(sidebar).toHaveClass(/is-open/)
    await guest.screenshot({ path: input.directory+'/navigation-overlay.png' })
    await guest.getByTestId('nav-sidebar').getByRole('button', { name: 'Закрыть навигацию', exact: true }).click()
    await expect(sidebar).not.toHaveClass(/is-open/)
    report.catalog_navigation_overlay = { opened_by_trigger: true, closed_by_button: true }
    console.log('stage=qa-member-navigation-overlay-complete')
  }

  await openNavigation(guest)
  await guest.getByRole('button', { name: 'Личные', exact: true }).click()
  const dmNavigation = guest.getByRole('navigation', { name: 'Личные сообщения' })
  await expect(dmNavigation).toBeVisible()
  await dmNavigation.getByRole('button', { name: 'Начать диалог', exact: true }).click()
  const dmStarter = guest.getByRole('dialog', { name: 'Новый личный диалог' })
  await expect(dmStarter.getByRole('button', { name: 'qa_admin', exact: true })).toBeVisible()
  assert.equal(await dmStarter.evaluate(element => element.matches(':modal')), true)
  assert.ok(await dmStarter.evaluate(element => element.scrollWidth <= element.clientWidth + 1))
  const starterBounds = await dmStarter.boundingBox()
  assert.ok(starterBounds.x >= 0 && starterBounds.x + starterBounds.width <= input.viewport.width)
  await guest.screenshot({ path: input.directory+'/dm-starter-dialog.png' })
  await guest.keyboard.press('Escape')
  await expect(dmStarter).not.toBeVisible()
  await expect(dmNavigation.getByRole('button', { name: 'Начать диалог', exact: true })).toBeFocused()
  if (input.viewport.has_touch) await dmNavigation.getByRole('button', { name: 'Начать диалог', exact: true }).tap()
  else await dmNavigation.getByRole('button', { name: 'Начать диалог', exact: true }).click()
  await dmStarter.getByRole('button', { name: 'qa_admin', exact: true }).click()
  report.dm_starter_modal = { top_layer: true, fits_viewport: true, escape_and_focus: true, touch: input.viewport.has_touch }
  await expect(guest.getByRole('heading', { name: 'qa_admin', exact: true })).toBeVisible()
  await expect(guest.getByText('Сообщений пока нет.', { exact: true })).toBeVisible()
  await expect(guest.locator('.conversation-header')).toBeInViewport({ ratio: 1 })
  await expect(guest.getByRole('textbox', { name: 'Сообщение', exact: true })).toBeInViewport({ ratio: 1 })
  console.log('stage=qa-member-dm-empty-complete')
  await guest.screenshot({ path: input.directory+'/dm-empty-conversation.png' })

  if (input.viewport.is_mobile && !(await guest.locator('.sidebar').evaluate(element => element.classList.contains('is-open')))) {
    await guest.getByRole('button', { name: 'Открыть навигацию', exact: true }).click()
  }
  const dmList = guest.getByRole('navigation', { name: 'Личные сообщения' })
  await expect(dmList.locator('.channel-button').filter({ hasText: 'qa_admin' })).toBeVisible()
  await guest.screenshot({ path: input.directory+'/dm-list.png' })
  if (input.viewport.is_mobile) await guest.getByTestId('nav-sidebar').getByRole('button', { name: 'Закрыть навигацию', exact: true }).click()

  const syntheticMessage = 'Синтетическое сообщение для QA'
  await guest.getByRole('textbox', { name: 'Сообщение' }).fill(syntheticMessage)
  const dmSentResponse = guest.waitForResponse(r => r.request().method()==='POST' && new URL(r.url()).pathname.endsWith('/messages') && new URL(r.url()).pathname.includes('/direct-messages/'))
  await guest.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  const dmSent = await dmSentResponse
  assert.equal(dmSent.status(), 201)
  const dmSentMessage = await dmSent.json()
  await expect(guest.getByText(syntheticMessage, { exact: true })).toBeVisible()
  console.log('stage=qa-member-dm-message-sent')
  await guest.screenshot({ path: input.directory+'/dm-conversation.png' })

  await openNavigation(guest)
  await guest.locator('.guild-search-button').click()
  const dmSearch = guest.getByTestId('search-panel')
  await expect(dmSearch).toBeVisible()
  await dmSearch.getByRole('searchbox', { name: 'Запрос', exact: true }).fill(syntheticMessage)
  const dmSearchResponse = guest.waitForResponse(r => r.request().method()==='GET' && new URL(r.url()).pathname==='/api/v1/search/messages')
  await dmSearch.getByRole('button', { name: 'Найти', exact: true }).click()
  const dmSearchBody = await (await dmSearchResponse).json()
  const dmSearchResult = dmSearch.locator('.search-result').filter({ hasText: syntheticMessage })
  await expect(dmSearchResult).toBeVisible()
  assert.ok(dmSearchBody.messages.some(message => message.id === dmSentMessage.id), 'The global search result must resolve the sent DM')
  await guest.screenshot({ path: input.directory+'/dm-search.png' })
  await dmSearchResult.getByRole('button').click()
  const dmTarget = guest.locator(`.direct-message-conversation .message-list [data-message-id="${dmSentMessage.id}"].message-search-target`)
  await expect(dmTarget).toContainText(syntheticMessage)
  await expect(guest.getByTestId('search-message-context')).toHaveCount(0)
  await expect(dmSearch).toBeHidden()
  await expect.poll(() => dmTarget.evaluate(row => {
    const viewport = row.closest('.message-list')
    const bounds = row.getBoundingClientRect(), view = viewport.getBoundingClientRect()
    return bounds.top >= view.top && bounds.bottom <= view.bottom
  })).toBe(true)
  await guest.screenshot({ path: input.directory+'/dm-search-result-in-conversation.png' })
  await expect(guest.locator('.direct-message-conversation > .conversation-header').getByRole('button', { name:'Найти сообщение', exact:true })).toHaveCount(0)
  await expect(guest.locator('.guild-search-button')).toHaveCount(1)
  await conversationHeaders(guest, input, report, 'DM')
  report.dm_full_app = { empty_conversation: true, list: true, sent_message: true, search: true, search_result_scrolls_into_conversation: true, flash_highlight: true, context_view_removed: true }
  console.log('stage=qa-member-dm-search-complete')

  await guest.screenshot({ path: input.directory+'/direct-message-header.png' })
  report.navigation_context = { ...report.navigation_context, direct_message_header: 'PASS' }
}
