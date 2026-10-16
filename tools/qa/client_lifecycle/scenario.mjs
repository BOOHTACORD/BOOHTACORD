import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'
import { api, channel, chromium, expect, login, openNavigation, origin, status } from './request.mjs'
import { guild } from './guild.mjs'
import { sessions } from './sessions.mjs'
import { searchTabs } from './search_tabs.mjs'
import { searchPresentation } from './search_presentation.mjs'
import { registration, rateLimit } from '../critical_client_acceptance/auth.mjs'
import { resetLinks } from '../critical_client_acceptance/reset.mjs'
import { bursts } from '../critical_client_acceptance/bursts.mjs'
import { media } from '../critical_client_acceptance/media.mjs'
import { prepareSessionRevoke, checkSessionRevoke } from '../critical_client_acceptance/teardown.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
assert.equal(origin, 'https://localhost:4810')
// The owned SFU advertises only loopback ICE candidates; permit that interface in this local fixture.
const browserOptions = { headless: true, args: ['--allow-loopback-in-peer-connection'] }
if (process.env.QA_BROWSER_EXECUTABLE) browserOptions.executablePath = process.env.QA_BROWSER_EXECUTABLE
const browser = await chromium.launch(browserOptions)
const report = {
  schema_version: 1,
  width: input.viewport.width,
  height: input.viewport.height,
  is_mobile: input.viewport.is_mobile,
  device_scale_factor: input.viewport.device_scale_factor,
  has_touch: input.viewport.has_touch,
  mocks: false,
  synthetic_accounts: true,
}
const redactions = [input.password]
try {
  const contextOptions = {
    ignoreHTTPSErrors: true,
    viewport: { width: input.viewport.width, height: input.viewport.height },
    isMobile: input.viewport.is_mobile,
    deviceScaleFactor: input.viewport.device_scale_factor,
    hasTouch: input.viewport.has_touch,
  }
  const contexts = await Promise.all([0, 1, 2].map(() => browser.newContext(contextOptions)))
  contexts.forEach(context => { context.setDefaultTimeout(15000); context.setDefaultNavigationTimeout(15000) })
  const [a, b, guest] = await Promise.all(contexts.map(context => context.newPage()))
  await login(a, 'qa_admin', input.password, input.directory)
  await login(b, 'qa_admin', input.password, input.directory)
  console.log('stage=two-admin-clients-authenticated')
  const flowAccount = input.critical ? await registration(browser, input, report) : null
  console.log('stage=registration-outcome-accepted')
  await expect.poll(async () => {
    try { return (await api(a, '/health')).status }
    catch { return 0 }
  }, { timeout: 15000 }).toBe(200)
  console.log('stage=browser-api-ready-after-registration')
  await guest.goto(origin)
  const expectedMemberCount = 20 + Number(Boolean(flowAccount))
  const value = await guild(a, b, guest, input.password, report, input.directory, expectedMemberCount)
  console.log('stage=reference-guild-journey-complete')
  await login(guest, 'qa_member', input.password, input.directory)
  console.log(`stage=qa-member-login:${input.viewport.width}`)
  await channel(guest, 'Text')
  console.log('stage=qa-member-text-channel-selected')
  const channelHistory = guest.getByRole('log', { name: 'История сообщений' })
  await expect(channelHistory).toContainText('Synthetic UIUX channel sample: readable conversation text.')
  console.log('stage=qa-member-message-history-visible')
  await guest.screenshot({ path: input.directory+'/channel-text.png' })
  const firstChannelMessage = guest.locator('.message-row')
    .filter({ hasText: 'Synthetic UIUX channel sample: readable conversation text.' }).first()
  await expect(firstChannelMessage).toBeVisible()
  console.log('stage=qa-member-first-message-visible')
  const messageActionsToggle = firstChannelMessage.locator('.message-actions-toggle')
  const messageActionButtons = firstChannelMessage.locator('.message-action-buttons')
  if (input.viewport.has_touch) {
    await messageActionsToggle.tap()
    await expect(firstChannelMessage.locator('.message-actions')).toHaveClass(/is-open/)
    console.log('stage=qa-member-message-actions-open-touch')
  } else {
    await firstChannelMessage.hover()
    await expect(firstChannelMessage.getByRole('button', { name: 'Ответить' })).toBeVisible()
    await expect(messageActionButtons).toHaveCSS('opacity', '1')
    console.log('stage=qa-member-message-actions-open-mouse')
  }
  await guest.screenshot({ path: input.directory+'/channel-text-actions.png' })
  if (input.viewport.has_touch) {
    await messageActionsToggle.tap()
    await expect(firstChannelMessage.locator('.message-actions')).not.toHaveClass(/is-open/)
  } else {
    await guest.mouse.move(0, 0)
    await expect(messageActionButtons).toHaveCSS('opacity', '0')
    await expect(messageActionButtons).toHaveCSS('pointer-events', 'none')
  }
  report.catalog_message_actions = { open: true, close: true, pointer: input.viewport.has_touch ? 'touch' : 'mouse' }
  console.log('stage=qa-member-message-actions-complete')
  await searchTabs(guest, input, report)
  await searchPresentation(guest, b, value, input, report)

  await channel(guest, 'Voice')
  await expect(guest.getByRole('heading', { name: 'Войти в голос', exact: true })).toBeVisible()
  await expect(guest.getByRole('button', { name: 'Войти', exact: true })).toBeVisible()
  await expect(guest.getByRole('button', { name: 'Без микрофона', exact: true })).toBeVisible()
  await guest.screenshot({ path: input.directory+'/voice-prejoin.png' })
  report.catalog_voice_prejoin = { channel_selected: true, connection_not_started: true, join_modes_visible: true }
  console.log('stage=qa-member-voice-prejoin-complete')

  const logMessages = [
    'Synthetic UIUX log sample: first readable entry.',
    'Synthetic UIUX log sample: labels, timestamps and actions.',
    'Synthetic UIUX log sample: wrapping at narrow viewports.',
  ]
  for (const body of logMessages) {
    status(await api(a, `/channels/${value.logChannelId}/messages`, 'POST', {
      client_message_id: randomUUID(), body,
    }), 201)
  }
  await channel(a, 'log')
  const logHistory = a.getByRole('log', { name: 'История сообщений' })
  await expect(logHistory).toContainText(logMessages[2])
  const firstLogMessage = a.locator('.message-row').filter({ hasText: logMessages[0] }).first()
  await expect(firstLogMessage).toBeVisible()
  if (input.viewport.has_touch) {
    await firstLogMessage.locator('.message-actions-toggle').tap()
    await expect(firstLogMessage.locator('.message-actions')).toHaveClass(/is-open/)
  } else {
    await firstLogMessage.hover()
  }
  await expect(firstLogMessage.getByRole('button', { name: 'Удалить', exact: true })).toBeVisible()
  await a.screenshot({ path: input.directory+'/channel-log.png' })
  report.catalog_channel_log = { synthetic_messages_visible: true, source_channel: 'log', admin_delete_action_reachable: true }
  console.log('stage=qa-member-channel-log-complete')

  if (input.viewport.is_mobile) {
    const sidebar = guest.locator('.sidebar')
    await guest.getByRole('button', { name: 'Открыть навигацию', exact: true }).click()
    await expect(sidebar).toHaveClass(/is-open/)
    await guest.screenshot({ path: input.directory+'/navigation-overlay.png' })
    await guest.getByRole('button', { name: 'Закрыть навигацию', exact: true }).click()
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
  console.log('stage=qa-member-dm-empty-complete')
  await guest.screenshot({ path: input.directory+'/dm-empty-conversation.png' })

  if (input.viewport.is_mobile && !(await guest.locator('.sidebar').evaluate(element => element.classList.contains('is-open')))) {
    await guest.getByRole('button', { name: 'Открыть навигацию', exact: true }).click()
  }
  const dmList = guest.getByRole('navigation', { name: 'Личные сообщения' })
  await expect(dmList.locator('.channel-button').filter({ hasText: 'qa_admin' })).toBeVisible()
  await guest.screenshot({ path: input.directory+'/dm-list.png' })
  if (input.viewport.is_mobile) await guest.getByRole('button', { name: 'Закрыть навигацию', exact: true }).click()

  const syntheticMessage = 'Синтетическое сообщение для QA'
  await guest.getByRole('textbox', { name: 'Сообщение' }).fill(syntheticMessage)
  await guest.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  await expect(guest.getByText(syntheticMessage, { exact: true })).toBeVisible()
  console.log('stage=qa-member-dm-message-sent')
  await guest.screenshot({ path: input.directory+'/dm-conversation.png' })

  await guest.getByRole('button', { name: 'Найти сообщение', exact: true }).click()
  const dmSearch = guest.locator('.direct-message-search')
  await expect(dmSearch).toBeVisible()
  await dmSearch.getByRole('searchbox', { name: 'Запрос' }).fill(syntheticMessage)
  await dmSearch.getByRole('button', { name: 'Найти', exact: true }).click()
  await expect(dmSearch.getByText('Найдено в этой странице: 1.', { exact: true })).toBeVisible()
  await expect(dmSearch.getByText(syntheticMessage, { exact: true })).toBeVisible()
  await guest.screenshot({ path: input.directory+'/dm-search.png' })
  await dmSearch.getByRole('button', { name: 'Открыть сообщение', exact: true }).click()
  const context = guest.getByTestId('search-message-context')
  await expect(context.getByText(syntheticMessage, { exact: true })).toBeVisible()
  await context.getByRole('button', { name: 'Вернуться к исходной позиции', exact: true }).click()
  await expect(dmSearch.getByRole('searchbox', { name: 'Запрос' })).toHaveValue(syntheticMessage)
  await expect(dmSearch.getByText(syntheticMessage, { exact: true })).toBeVisible()
  report.dm_full_app = { empty_conversation: true, list: true, sent_message: true, search: true, context_return_preserves_search: true }
  console.log('stage=qa-member-dm-search-complete')

  await guest.screenshot({ path: input.directory+'/direct-message-header.png' })
  report.navigation_context = { ...report.navigation_context, direct_message_header: 'PASS' }

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
  await expect(globalSearch.getByRole('button', { name: 'Найти', exact: true })).toBeDisabled()
  await guest.screenshot({ path: input.directory+'/global-search.png' })
  await globalSearch.getByRole('searchbox', { name: 'Запрос' }).fill('Synthetic UIUX channel sample')
  await globalSearch.getByRole('button', { name: 'Найти', exact: true }).click()
  const globalResults = globalSearch.locator('.search-result')
  await expect(globalResults.first()).toBeVisible()
  await globalResults.first().getByRole('button').click()
  await expect(guest.getByTestId('search-message-context')).toBeVisible()
  await guest.screenshot({ path: input.directory+'/global-search-result-context.png' })
  console.log('stage=qa-member-global-search-complete')
  report.global_search_full_app = {
    panel: true,
    defaultGlobalScope: true,
    authorAttachmentDateFilters: true,
    disposableApiResults: true,
    resultOpensOriginalContext: true,
  }

  const denied = await api(guest, '/admin/guild-settings', 'PATCH', {
    name: 'MemberOverwrite', expected_revision: value.revision,
  })
  status(denied, 403)
  report.guild.member_denied = true
  if (input.critical) {
    await bursts(a, b, value.channelId, report, input.directory)
    console.log('stage=actual-protected-bursts-accepted')
    await media(a, b, guest, value.channelId, report, input)
    console.log('stage=actual-media-faults-accepted')
    await resetLinks(browser, a, flowAccount.account_id, input, report, redactions)
    console.log('stage=actual-reset-links-accepted')
  }
  await sessions(a, b, guest, report, input.directory, redactions, input.critical ? {
    prepare: () => prepareSessionRevoke(b), check: () => checkSessionRevoke(b, report),
  } : undefined)
  const refreshed = (await api(a, '/guild-profile')).body
  assert.equal(refreshed.name, 'Автономная гильдия')
  const anonymous = await browser.newContext(contextOptions)
  const auth = await anonymous.newPage()
  await auth.goto(origin)
  await expect(auth.locator('.authentication-brand .guild-profile-name')).toHaveText(refreshed.name)
  await expect(auth.locator('.authentication-intro')).toContainText(refreshed.name)
  await auth.screenshot({ path: input.directory+'/authentication.png' })
  await anonymous.close()
  if (input.critical) await rateLimit(browser, a, input, report)
  report.status = 'PASS'
  writeFileSync(input.directory+'/browser.json', JSON.stringify(report, null, 2)+'\n')
  // Private handoff is temporary, never retained as evidence or printed.
  writeFileSync(process.env.QA_PRIVATE, JSON.stringify({ ...value, password: input.password }), { mode: 0o600 })
  console.log('Actual browser lifecycle PASS')
} catch (error) {
  for (const context of browser.contexts()) redactions.push(...(await context.cookies()).map(cookie => cookie.value))
  let message = String(error)
  for (const value of redactions.filter(Boolean)) message = message.split(value).join('[redacted]')
  console.error(message)
  if (error instanceof Error && typeof error.stack === 'string') {
    let frames = error.stack.split('\n').slice(1, 9).join('\n')
    for (const value of redactions.filter(Boolean)) frames = frames.split(value).join('[redacted]')
    if (frames) console.error(frames)
  }
  process.exitCode = 1
} finally { await browser.close() }
