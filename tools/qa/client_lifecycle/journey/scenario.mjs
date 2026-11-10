import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { api, chromium, expect, login, origin, status } from '../request.mjs'
import { guild } from '../guild.mjs'
import { personalSettings } from '../settings_hierarchy.mjs'
import { sessions } from '../sessions.mjs'
import { registration, rateLimit } from '../../critical_client_acceptance/auth.mjs'
import { resetLinks } from '../../critical_client_acceptance/reset.mjs'
import { bursts } from '../../critical_client_acceptance/bursts.mjs'
import { media } from '../../critical_client_acceptance/media.mjs'
import { prepareSessionRevoke, checkSessionRevoke } from '../../critical_client_acceptance/teardown.mjs'
import { memberChannel } from './member_channel.mjs'
import { memberLog } from './member_log.mjs'
import { memberDM } from './member_dm.mjs'
import { memberGlobalSearch } from './member_global_search.mjs'
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
  await personalSettings(a, input, report)
  await memberChannel(guest, b, value, input, report)
  await memberLog(a, value, input, report)
  await memberDM(guest, input, report)
  await memberGlobalSearch(guest, input, report)

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
