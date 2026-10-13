// Real Web canvas -> SFU -> native reader counterpart; no physical FPS claim.
import assert from 'node:assert/strict'
import {readFileSync, writeFileSync, mkdirSync, existsSync, renameSync} from 'node:fs'
import {createRequire} from 'node:module'
import {resolve, relative} from 'node:path'

const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
const {chromium} = require('@playwright/test')
const input = JSON.parse(readFileSync(process.env.QA_STAGE_INPUT, 'utf8'))
const out = resolve(process.env.QA_DESCRIPTOR_REVERSE_OUT)
assert.ok(relative(resolve('.out'), out) && !relative(resolve('.out'), out).startsWith('..'), 'Ignored owned output directory required')
const seconds = Number(process.env.QA_DESCRIPTOR_REVERSE_DURATION ?? '120')
const motionSeconds = Number(process.env.QA_DESCRIPTOR_REVERSE_MOTION ?? Math.min(70, Math.floor(seconds / 2)))
assert.ok(Number.isInteger(motionSeconds) && motionSeconds >= 15 && motionSeconds <= 70 && motionSeconds < seconds, 'Bounded mode observation interval required')
assert.ok(Number.isInteger(seconds) && seconds >= 60 && seconds <= 180, 'Bounded reverse duration required')
mkdirSync(out, {recursive: true})
const prior = ['web-sender-ready.json', 'web-sender.json'].filter(name => existsSync(out + '/' + name))
if (prior.length) {
  const archive = out + '/previous/' + Date.now()
  mkdirSync(archive, {recursive: true})
  for (const name of prior) renameSync(out + '/' + name, archive + '/' + name)
}
const report = {schema_version: 1, status: 'RUNNING', source: 'Headless Web synthetic canvas with production metadata publisher/client and real Go/SFU; actual native reader evidence joined separately', physical_capture_or_presentation: 'NOT_RUN', browser_TLS_validation: 'Owned test context ignoreHTTPSErrors; not browser trust-chain acceptance', metadata_HTTP_statuses: [], cleanup_errors: []}
const origin = 'https://localhost:5060'
const browser = await chromium.launch({args: ['--autoplay-policy=no-user-gesture-required', '--explicitly-allowed-ports=5060']})
const context = await browser.newContext({ignoreHTTPSErrors: true})
let page, lease, authenticated = false, phase = 'login', closing
async function request(path, method = 'GET', body) {
  return context.request.fetch(origin + '/api/v1' + path, {method, timeout: 10000, maxRedirects: 0, headers: {Origin: origin, 'Content-Type': 'application/json'}, ...(body === undefined ? {} : {data: body})})
}
async function api(path, method = 'GET', body) {
  const response = await request(path, method, body)
  if (!response.ok()) report.API_failure = {actual_HTTP: response.status(), retry_after_seconds: /^\d+$/.test(response.headers()['retry-after'] ?? '') ? Number(response.headers()['retry-after']) : null}
  assert.ok(response.ok(), 'Owned API operation failed')
  return response.status() === 204 ? null : response.json()
}
async function close() {
  if (closing) return closing
  closing = (async () => {
    if (page) await page.evaluate(() => window.descriptorSender.stop()).catch(error => report.cleanup_errors.push(error.name))
    if (lease) await api(`/voice/leases/${lease.id}`, 'DELETE').catch(error => report.cleanup_errors.push(error.name))
    if (authenticated) await api('/auth/logout', 'POST').catch(error => report.cleanup_errors.push(error.name))
    await context.close().catch(error => report.cleanup_errors.push(error.name))
    await browser.close().catch(error => report.cleanup_errors.push(error.name))
    report.owned_context_closed = true
    if (report.cleanup_errors.length) {report.status = 'FAIL'; process.exitCode = 1}
    writeFileSync(out + '/web-sender.json', JSON.stringify(report, null, 2) + '\n')
  })()
  return closing
}
process.once('SIGTERM', () => {report.status = 'FAIL'; report.failed_phase = phase; report.error_type = 'CoordinatorStoppedOwnedSource'; void close().finally(() => process.exit(143))})
try {
  // Reuse exactly the root ACL fixture created in this same disposable stack.
  // Never register/rotate a fresh identity to bypass admission limits.
  await api('/auth/login', 'POST', {login: 'qa_descriptor_acl_a', password: input.password})
  authenticated = true
  const session = await api('/auth/session')
  assert.equal(session.authenticated, true)
  await api('/me', 'PATCH', {display_name: 'QA_DESCRIPTOR_SOURCE'})
  const topology = await api('/channels')
  const channel = topology.categories.flatMap(value => value.channels).find(value => value.name === 'QaVoice' && value.kind === 'VOICE')
  assert.ok(channel, 'Owned voice channel required')
  lease = await api(`/voice/channels/${channel.id}/leases`, 'POST', {transfer: true})
  const credential = await api(`/voice/leases/${lease.id}/credential`, 'POST')
  page = await context.newPage()
  await page.exposeFunction('qaProtectedDescriptorWrite', async descriptor => {
    assert.equal(descriptor?.schema_version, 1, 'Versioned descriptor required')
    const response = await request(`/voice/leases/${lease.id}/screen-profile/v1`, 'PUT', descriptor)
    report.metadata_HTTP_statuses.push(response.status())
    return response.status()
  })
  phase = 'source_and_motion_descriptor'
  await page.goto('http://127.0.0.1:5066/tests/screen_profile/descriptor_sender.html')
  report.initial = await page.evaluate(input => window.descriptorSender.start(input), {...credential, lease: lease.id, owner: {originId: origin, accountId: session.account_id, roomId: 'voice:' + channel.id}})
  assert.equal(report.initial.mode, 'motion')
  assert.ok(report.initial.fresh_encoder_limits.length === 1)
  writeFileSync(out + '/web-sender-ready.json', JSON.stringify({ready: true, mode: 'motion', profile: 'P1080_60'}) + '\n')
  phase = 'await_native_reader_and_mode_update'
  await page.waitForTimeout(motionSeconds * 1000)
  report.updated = await page.evaluate(() => window.descriptorSender.metadata('text'))
  assert.equal(report.updated.mode, 'text')
  await page.waitForTimeout((seconds - motionSeconds) * 1000)
  report.last = await page.evaluate(() => window.descriptorSender.sample())
  assert.ok(report.last.generatedFrames > report.initial.generatedFrames, 'Current synthetic source did not advance')
  assert.ok(report.metadata_HTTP_statuses.length >= 2 && report.metadata_HTTP_statuses.every(value => value === 204))
  report.status = 'PASS_WEB_COUNTERPART_ONLY'
  report.duration_seconds = seconds
  report.motion_seconds = motionSeconds
} catch (error) {
  report.status = 'FAIL'
  report.failed_phase = phase
  report.error_type = error.name
  process.exitCode = 1
} finally {await close()}
