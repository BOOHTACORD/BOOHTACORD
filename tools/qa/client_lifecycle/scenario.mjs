import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { api, chromium, expect, login, openNavigation, origin, status } from './request.mjs'
import { guild } from './guild.mjs'
import { sessions } from './sessions.mjs'
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
  await login(a, 'qa_admin', input.password)
  await login(b, 'qa_admin', input.password)
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
  await login(guest, 'qa_member', input.password)
  await openNavigation(guest)
  await guest.getByRole('button', { name: 'Личные', exact: true }).click()
  const dmNavigation = guest.getByRole('navigation', { name: 'Личные сообщения' })
  await expect(dmNavigation).toBeVisible()
  await dmNavigation.getByRole('button', { name: 'Начать диалог', exact: true }).click()
  const dmStarter = guest.getByRole('dialog', { name: 'Новый личный диалог' })
  await dmStarter.getByRole('button', { name: 'qa_admin', exact: true }).click()
  await expect(guest.getByRole('heading', { name: 'qa_admin', exact: true })).toBeVisible()
  await expect(guest.getByText('Сообщений пока нет.', { exact: true })).toBeVisible()
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
  process.exitCode = 1
} finally { await browser.close() }
