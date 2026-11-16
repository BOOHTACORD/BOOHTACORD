// Production Web viewer for the physical macOS Flutter sender pairing.
import assert from 'node:assert/strict'
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs'
import {createRequire} from 'node:module'
import {relative, resolve} from 'node:path'
import {observeNativeScreenTelemetry, requireNativeWebTelemetryEvidence} from './stage_receiver_policy.mjs'
import {selectVisibleStream} from '../critical_client_acceptance/select_stream.mjs'

const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
const {chromium, expect} = require('@playwright/test')
const input = JSON.parse(readFileSync(process.env.QA_STAGE_INPUT, 'utf8'))
const index = Number(process.env.QA_STAGE_INDEX)
const output = resolve(process.env.QA_STAGE_OUT ?? '')
const screenshot = resolve(process.env.QA_STAGE_SCREENSHOT ?? '')
assert.ok(Number.isInteger(index) && index >= 1 && index <= 20)
const outputRelative = relative(process.cwd() + '/.out', output)
assert.ok(outputRelative && !outputRelative.startsWith('..'), 'Ignored owned output directory required')
const screenshotRelative = relative(output, screenshot)
assert.ok(screenshotRelative && !screenshotRelative.startsWith('..'), 'Screenshot must stay in the owned output directory')
mkdirSync(output, {recursive: true})

const origin = 'https://localhost:5060'
const report = {
  status: 'RUNNING',
  scope: 'Physical macOS Flutter screen sender to authenticated production Web viewer; flow evidence only, no media-quality or capacity claim',
  sender_platform: 'macos',
  sender_client: 'flutter',
  web_session_authenticated: false,
  voice_connected: false,
  selected_stream_decoded: false,
  realtime_event_count: 0,
  scoped_native_event: false,
  fresh_sender_sample_visible: false,
  target_labeled_separately: false,
  no_sensitive_fields_in_receipt: true,
}
const browser = await chromium.launch({args: ['--autoplay-policy=no-user-gesture-required', '--explicitly-allowed-ports=5060']})
const context = await browser.newContext({ignoreHTTPSErrors: true, viewport: {width: 1440, height: 900}})
let page, authenticated = false, phase = 'login', realtimeReady = false, nativeEventScope = false
let closing

async function api(path, method = 'GET', body) {
  const response = await context.request.fetch(origin + '/api/v1' + path, {
    method, timeout: 10000, maxRedirects: 0,
    headers: {Origin: origin, 'Content-Type': 'application/json'},
    ...(body === undefined ? {} : {data: body}),
  })
  assert.ok(response.ok(), `Owned Web viewer API HTTP${response.status()}`)
  return response.status() === 204 ? null : response.json()
}

async function closeOwned() {
  if (closing) return closing
  closing = (async () => {
    if (page) {
      const leave = page.getByTestId('voice-dock').getByRole('button', {name: 'Выйти из голосового канала', exact: true})
      if (await leave.count().catch(() => 0)) await leave.click().catch(() => undefined)
    }
    if (authenticated) await api('/auth/logout', 'POST').catch(() => undefined)
    await context.close().catch(() => undefined)
    await browser.close().catch(() => undefined)
    writeFileSync(output + `/receiver-${index}.json`, JSON.stringify(report, null, 2) + '\n')
  })()
  return closing
}

process.once('SIGTERM', () => {
  report.status = 'FAIL'
  report.failed_phase = phase
  report.error_type = 'CoordinatorStoppedOwnedWebViewer'
  void closeOwned().finally(() => process.exit(143))
})

function observeRealtime(socket) {
  try {
    const url = new URL(socket.url())
    if (url.origin !== 'wss://localhost:5060' || url.pathname !== '/api/v1/realtime') return
  } catch { return }
  socket.on('framereceived', frame => {
    if (typeof frame.payload !== 'string') return
    try {
      const event = JSON.parse(frame.payload)
      if (event.kind === 'connection.ready') realtimeReady = true
      if (event.kind !== 'screen_telemetry.updated') return
      report.realtime_event_count++
      if (observeNativeScreenTelemetry(report, event)) nativeEventScope = true
    } catch { /* Do not retain or print raw realtime payloads. */ }
  })
}

try {
  phase = 'owned fixture authentication'
  const login = await context.request.fetch(origin + '/api/v1/auth/login', {
    method: 'POST', timeout: 10000, maxRedirects: 0,
    headers: {Origin: origin, 'Content-Type': 'application/json'},
    data: {login: 'qa_sender_peer', password: input.password},
  })
  assert.equal(login.status(), 204, 'Existing owned Web peer login required')
  authenticated = true
  const session = await api('/auth/session')
  assert.equal(session.authenticated, true)
  report.web_session_authenticated = true

  page = await context.newPage()
  page.on('websocket', observeRealtime)
  phase = 'production Web application'
  await page.goto(origin)
  await expect(page.getByTestId('app-shell')).toBeVisible({timeout: 20000})
  await expect.poll(() => realtimeReady, {timeout: 20000}).toBe(true)

  phase = 'join owned voice channel'
  const channel = page.locator('.channel-button').filter({hasText: 'QaVoice'}).first()
  await expect(channel).toBeVisible({timeout: 15000})
  await channel.click()
  await page.getByRole('button', {name: 'Без микрофона', exact: true}).click()
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', {timeout: 25000})
  report.voice_connected = true

  writeFileSync(output + `/receiver-${index}-ready.json`, JSON.stringify({ready: true, case: index, production_web_viewer: true}) + '\n')
  phase = 'select native screen'
  await expect.poll(async () =>
    (await page.locator('[data-testid=participant-screen-preview]').count()) +
    (await page.locator('[data-testid=stream-select]').count()),
  {timeout: 60000}).toBeGreaterThan(0)
  await selectVisibleStream(page)
  const video = page.locator('video.screen-player').first()
  await expect.poll(() => video.evaluate(element => element.videoWidth > 0 && element.getVideoPlaybackQuality().totalVideoFrames > 0), {timeout: 30000}).toBe(true)
  report.selected_stream_decoded = true

  phase = 'selected stream sender telemetry'
  const eventDeadline = Date.now() + 30000
  while (Date.now() < eventDeadline && report.realtime_event_count === 0) await page.waitForTimeout(200)
  assert.ok(report.realtime_event_count > 0, 'No screen_telemetry.updated event arrived on the authenticated WebSocket')
  assert.equal(nativeEventScope, true, 'Realtime telemetry did not identify the native macOS Flutter sender')
  report.scoped_native_event = nativeEventScope
  phase = 'open selected stream diagnostics'
  await page.locator('.screen-stage').hover()
  await expect(page.locator('summary[aria-label="Статистика"]')).toBeVisible()
  await page.locator('summary[aria-label="Статистика"]').click()
  const panel = page.getByRole('dialog', {name: 'Статистика трансляции'})
  await expect(panel.getByRole('heading', {name: 'Отправитель', exact: true})).toBeVisible()
  const targetText = await panel.locator('.screen-diagnostics-target').innerText()
  report.target_labeled_separately = targetText.startsWith('Цель:')
  assert.equal(report.target_labeled_separately, true, 'Configured target must remain distinct from sender measurements')
  await page.screenshot({path: screenshot})

  phase = 'selected sender sample freshness'
  const senderSummary = panel.locator('.screen-diagnostics-summary__group[aria-labelledby="screen-summary-sender"]')
  await expect.poll(() => senderSummary.innerText(), {timeout: 30000}).toContain('Актуально')
  const senderText = await senderSummary.innerText()
  assert.match(senderText, /измерено/i, 'Selected native sender measurements were not displayed as measured')
  assert.doesNotMatch(senderText, /нет измерений от отправителя/i)
  report.fresh_sender_sample_visible = true

  report.status = 'PASS'
  requireNativeWebTelemetryEvidence(report)
} catch (error) {
  report.status = 'FAIL'
  report.failed_phase = phase
  report.error_type = error.name
  process.exitCode = 1
} finally { await closeOwned() }
