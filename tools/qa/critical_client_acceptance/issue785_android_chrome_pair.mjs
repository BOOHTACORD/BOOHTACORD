import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { execFileSync, spawnSync } from 'node:child_process'
import { pathToFileURL } from 'node:url'

const repo = process.cwd()
const input = JSON.parse(fs.readFileSync('/private/tmp/issue785-browser-pair.json', 'utf8'))
process.env.QA_ORIGIN = input.origin
const require = createRequire(path.join(repo, 'clients/web/package.json'))
const { chromium, expect } = require('@playwright/test')
const { api, login, channel, status } = await import(pathToFileURL(path.join(repo, 'tools/qa/client_lifecycle/request.mjs')))
const { prepareOwnedLoopback } = await import(pathToFileURL(path.join(repo, 'tools/qa/client_lifecycle/loopback_navigation.mjs')))
const origin = input.origin
const outputDir = path.join(repo, '.out/local-features/issue785-browser-paired-no-cdp-immediate')
fs.mkdirSync(outputDir, { recursive: true })
const screenshot = path.join(outputDir, 'android-chrome-paired-audio-after-resume.png')
const account = 'qa_rx_' + String(Date.now()).slice(-8)
const roomName = 'Issue785Pair' + String(Date.now()).slice(-7)
let voiceChannelId
let browser, senderContext, senderPage, androidBrowser, androidContext, androidPage
let androidCdpDetachedForBackground = false

const installObserver = () => {
  window.__qaPeers = []
  window.__qaVisibility = []
  window.__qaLifecycle = []
  window.__qaRecordLifecycle = type => {
    const observation = { type, state: document.visibilityState, at: Date.now() }
    window.__qaLifecycle.push(observation)
    try {
      const events = JSON.parse(localStorage.getItem('issue785_lifecycle_events') ?? '[]')
      events.push(observation)
      localStorage.setItem('issue785_lifecycle_events', JSON.stringify(events))
    } catch { /* The in-memory observation remains available if storage is unavailable. */ }
  }
  window.__qaRecordVisibility = () => {
    const state = document.visibilityState
    window.__qaVisibility.push(state)
    window.__qaRecordLifecycle('visibilitychange')
    try {
      const events = JSON.parse(localStorage.getItem('issue785_visibility_events') ?? '[]')
      events.push({ state, at: Date.now() })
      localStorage.setItem('issue785_visibility_events', JSON.stringify(events))
    } catch { /* The in-memory observation remains available if storage is unavailable. */ }
  }
  document.addEventListener('visibilitychange', window.__qaRecordVisibility)
  document.addEventListener('freeze', () => window.__qaRecordLifecycle('freeze'))
  document.addEventListener('resume', () => window.__qaRecordLifecycle('resume'))
  window.addEventListener('pagehide', () => window.__qaRecordLifecycle('pagehide'))
  window.addEventListener('pageshow', () => window.__qaRecordLifecycle('pageshow'))
  window.addEventListener('online', () => window.__qaRecordLifecycle('online'))
  const Native = window.RTCPeerConnection
  window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
    const peer = Reflect.construct(target, args)
    window.__qaPeers.push(peer)
    return peer
  } })
}

async function audioCounters(page) {
  return page.evaluate(async () => {
    const totals = { peerConnections: 0, activePeerConnections: 0, connectedPeerConnections: 0,
      inboundAudioPackets: 0, inboundAudioBytes: 0, outboundAudioPackets: 0, outboundAudioBytes: 0 }
    for (const peer of window.__qaPeers ?? []) {
      totals.peerConnections++
      if (peer.connectionState !== 'closed') totals.activePeerConnections++
      if (peer.connectionState === 'connected') totals.connectedPeerConnections++
      if (peer.connectionState === 'closed') continue
      try {
        const stats = await peer.getStats()
        for (const report of stats.values()) {
          if (report.type === 'inbound-rtp' && (report.kind === 'audio' || report.mediaType === 'audio')) {
            totals.inboundAudioPackets += Number(report.packetsReceived ?? 0)
            totals.inboundAudioBytes += Number(report.bytesReceived ?? 0)
          }
          if (report.type === 'outbound-rtp' && (report.kind === 'audio' || report.mediaType === 'audio')) {
            totals.outboundAudioPackets += Number(report.packetsSent ?? 0)
            totals.outboundAudioBytes += Number(report.bytesSent ?? 0)
          }
        }
      } catch { /* A closed peer can disappear between state and stats reads. */ }
    }
    return totals
  })
}

async function androidDomClick(locator) { await locator.evaluate(element => element.click()) }

async function joinAs(page, username, mic) {
  if (!(await page.getByTestId('app-shell').count())) await login(page, username, input.password)
  await channel(page, roomName)
  const prejoin = page.locator('.voice-prejoin')
  await expect(prejoin).toBeVisible()
  await prejoin.getByRole('button', { name: mic ? 'Войти' : 'Без микрофона', exact: true }).click()
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })
}

async function joinAndroidAsListener(page) {
  await prepareOwnedLoopback(page, origin)
  await page.getByLabel('Логин', { exact: true }).fill(account)
  await page.getByLabel('Пароль', { exact: true }).fill(input.password)
  await androidDomClick(page.getByRole('button', { name: 'Войти', exact: true }))
  await expect(page.getByTestId('app-shell')).toBeVisible()

  const guildHeader = page.locator('.guild-header')
  if (!(await guildHeader.isVisible())) {
    const open = page.getByRole('button', { name: 'Открыть навигацию', exact: true })
    await androidDomClick(open)
    await expect(guildHeader).toBeVisible()
  }
  const voiceChannel = page.locator(`.channel-button[data-channel-id="${voiceChannelId}"]`).first()
  await expect(voiceChannel).toBeVisible()
  await androidDomClick(voiceChannel)
  const prejoin = page.locator('.voice-prejoin')
  await expect(prejoin).toBeVisible()
  await androidDomClick(prejoin.getByRole('button', { name: 'Без микрофона', exact: true }))
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })
}

async function connectAndroidChrome({ addForward = false } = {}) {
  if (addForward) execFileSync('adb', ['forward', 'tcp:9222', 'localabstract:chrome_devtools_remote'])
  androidBrowser = await chromium.connectOverCDP('http://127.0.0.1:9222')
  androidContext = androidBrowser.contexts()[0]
  assert.ok(androidContext, 'Android Chrome must expose a browser context')
  androidContext.setDefaultTimeout(15000)
  const pages = androidContext.pages()
  androidPage = pages.find(page => page.url().startsWith(origin)) ?? pages.at(-1) ?? await androidContext.newPage()
  for (const page of pages) if (page !== androidPage) await page.close().catch(() => undefined)
  await androidPage.bringToFront()
  const security = await androidBrowser.newBrowserCDPSession()
  await security.send('Security.setIgnoreCertificateErrors', { ignore: true })
}

try {
  browser = await chromium.launch({ headless: true, args: [
    '--allow-loopback-in-peer-connection', '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream'
  ] })
  senderContext = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } })
  await senderContext.grantPermissions(['microphone'], { origin })
  await senderContext.addInitScript(installObserver)
  senderContext.setDefaultTimeout(15000)
  senderPage = await senderContext.newPage()
  await login(senderPage, 'qa_admin', input.password)
  console.log('stage=sender-authenticated')
  const member = await api(senderPage, '/auth/register', 'POST', { login: account, password: input.password })
  status(member, 201)
  console.log('stage=receiver-account-created')
  const category = await api(senderPage, '/admin/categories', 'POST', { name: roomName })
  status(category, 201)
  const voice = await api(senderPage, `/admin/categories/${category.body.id}/channels`, 'POST', { name: roomName, kind: 'VOICE' })
  status(voice, 201)
  voiceChannelId = voice.body.id
  await senderPage.reload()
  await expect(senderPage.getByTestId('app-shell')).toBeVisible()
  console.log('stage=voice-channel-created')
  await joinAs(senderPage, 'qa_admin', true)
  await expect.poll(async () => (await audioCounters(senderPage)).outboundAudioBytes, { timeout: 20000 }).toBeGreaterThan(0)
  console.log('stage=synthetic-audio-published')

  await connectAndroidChrome()
  await androidContext.clearCookies({ domain: 'localhost' })
  await androidPage.goto('about:blank')
  await androidContext.addInitScript(installObserver)
  console.log('stage=android-cdp-connected url=' + androidPage.url())
  await joinAndroidAsListener(androidPage)
  await expect.poll(async () => (await audioCounters(androidPage)).inboundAudioBytes, { timeout: 25000 }).toBeGreaterThan(0)

  const resumeButton = androidPage.getByRole('button', { name: 'Возобновить звук', exact: true })
  const resumeGestureNeeded = await resumeButton.isVisible().catch(() => false)
  const before = await audioCounters(androidPage)
  const senderBefore = await audioCounters(senderPage)
  assert.ok(before.inboundAudioPackets > 0 && before.inboundAudioBytes > 0, 'Android Chrome must receive synthetic audio before backgrounding')
  await androidPage.evaluate(() => {
    window.__qaVisibility = [document.visibilityState]
    window.__qaLifecycle = []
    localStorage.setItem('issue785_visibility_events', JSON.stringify([{ state: document.visibilityState, at: Date.now() }]))
    localStorage.setItem('issue785_lifecycle_events', JSON.stringify([{ type: 'baseline', state: document.visibilityState, at: Date.now() }]))
  })
  assert.equal(await androidPage.evaluate(() => document.visibilityState), 'visible', 'Chrome receiver must be foregrounded before backgrounding')
  console.log('stage=android-chrome-receiving-audio')

  // Let Android Chrome run without a DevTools connection while Home is active.
  await androidBrowser.close()
  androidBrowser = null
  androidContext = null
  androidPage = null
  androidCdpDetachedForBackground = true
  execFileSync('adb', ['forward', '--remove', 'tcp:9222'], { stdio: 'ignore' })
  console.log('stage=android-cdp-detached')
  execFileSync('adb', ['shell', 'input', 'keyevent', '3'], { stdio: 'ignore' })
  let homeActivity = ''
  for (let attempt = 0; attempt < 20; attempt++) {
    homeActivity = execFileSync('adb', ['shell', 'dumpsys', 'activity', 'activities'], { encoding: 'utf8' })
    if (/topResumedActivity=.*(?:nexuslauncher|Launcher)/i.test(homeActivity)) break
    await new Promise(resolve => setTimeout(resolve, 500))
  }
  assert.match(homeActivity, /topResumedActivity=.*(?:nexuslauncher|Launcher)/i, 'Android Home must actually be foregrounded')
  await new Promise(resolve => setTimeout(resolve, 300000))
  const foreground = spawnSync('adb', ['shell', 'am', 'start', '-n', 'com.android.chrome/com.google.android.apps.chrome.Main'], { stdio: 'ignore' })
  if (foreground.error) throw foreground.error
  await new Promise(resolve => setTimeout(resolve, 1500))
  await connectAndroidChrome({ addForward: true })
  androidCdpDetachedForBackground = false
  await androidContext.addInitScript(installObserver)
  console.log('stage=android-cdp-reconnected')
  await androidPage.bringToFront()
  await expect.poll(() => androidPage.evaluate(() => document.visibilityState), { timeout: 20000 }).toBe('visible')
  const atResume = await audioCounters(androidPage)
  await expect(androidPage.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })
  await expect.poll(async () => (await audioCounters(androidPage)).inboundAudioBytes, { timeout: 20000 }).toBeGreaterThan(atResume.inboundAudioBytes)
  const resumedSamples = [await audioCounters(androidPage)]
  for (let sample = 0; sample < 3; sample++) {
    await new Promise(resolve => setTimeout(resolve, 10000))
    const current = await audioCounters(androidPage)
    assert.ok(current.inboundAudioPackets > resumedSamples.at(-1).inboundAudioPackets, 'Audio packets must advance during each 10-second interval after resume')
    resumedSamples.push(current)
  }
  const after = await audioCounters(androidPage)
  const senderAfter = await audioCounters(senderPage)
  const lifecycleObservation = await androidPage.evaluate(() => ({
    inMemory: window.__qaVisibility ?? [],
    persisted: JSON.parse(localStorage.getItem('issue785_visibility_events') ?? '[]'),
    lifecycle: JSON.parse(localStorage.getItem('issue785_lifecycle_events') ?? '[]'),
  }))
  const visibilityEvents = lifecycleObservation.persisted.map(event => event.state)
  console.log('COUNTERS=' + JSON.stringify({ before, atResume, resumedSamples, after, senderBefore, senderAfter, lifecycleObservation }))
  if (visibilityEvents.includes('hidden')) assert.ok(visibilityEvents.includes('visible'), 'A hidden document must return to visible')
  assert.ok(after.activePeerConnections <= 1, 'Resume must not leave duplicate active peer connections')
  assert.ok(senderAfter.outboundAudioBytes > senderBefore.outboundAudioBytes, 'The paired sender must continue delivering synthetic audio')
  await androidPage.screenshot({ path: screenshot })
  const result = {
    status: 'PASS_SCOPED', issue: 785,
    environment: { android: '15/API 35 emulator', chrome: '124.0.6367.219', receiver: 'Android Chrome', sender: 'Playwright Chromium with synthetic microphone' },
    scenario: { senderMic: true, receiverListenerOnly: true, backgroundSeconds: 300, homeActivityObserved: true, cdpDisconnectedDuringBackground: !androidCdpDetachedForBackground, resumeGestureNeeded, visibilityEvents, lifecycleEvents: lifecycleObservation.lifecycle },
    mediaCounters: { receiverBefore: before, receiverAtResume: atResume, receiverAfter: after, senderBefore, senderAfter },
    mediaResult: 'PASS_SCOPED',
    lifecycleResult: visibilityEvents.includes('hidden') && visibilityEvents.includes('visible') ? 'PASS_SCOPED' : 'NOT_OBSERVED',
    screenshot: path.relative(repo, screenshot)
  }
  fs.writeFileSync(path.join(outputDir, 'result.json'), JSON.stringify(result, null, 2) + '\n')
  console.log('RESULT=' + JSON.stringify(result))
} catch (error) {
  const inputPassword = input.password
  const message = String(error instanceof Error ? error.message : error).split(inputPassword).join('[redacted]')
  console.error('PAIR_TEST_FAILED=' + message)
  if (androidPage) {
    console.error('ANDROID_URL=' + androidPage.url())
    console.error('ANDROID_INPUTS=' + JSON.stringify(await androidPage.locator('input').evaluateAll(nodes => nodes.map(node => ({ type: node.type, name: node.name, disabled: node.disabled, visible: Boolean(node.offsetWidth || node.offsetHeight) }))).catch(() => [])))
    await androidPage.screenshot({ path: path.join(outputDir, 'android-chrome-pair-failure.png') }).catch(() => undefined)
  }
  process.exitCode = 1
} finally {
  try {
    if (androidCdpDetachedForBackground) {
      try {
        await connectAndroidChrome({ addForward: true })
        androidCdpDetachedForBackground = false
      } catch { /* Cleanup continues even if Android Chrome is no longer reachable. */ }
    }
    if (senderPage && await senderPage.getByTestId('voice-dock').count().catch(() => 0)) {
      const leave = senderPage.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true })
      if (await leave.count().catch(() => 0)) await leave.click({ timeout: 5000 }).catch(() => undefined)
    }
    if (androidPage && await androidPage.getByTestId('voice-dock').count().catch(() => 0)) {
      const leave = androidPage.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true })
      if (await leave.count().catch(() => 0)) await leave.click({ timeout: 5000 }).catch(() => undefined)
      await androidPage.evaluate(() => { try { localStorage.clear(); sessionStorage.clear() } catch {} }).catch(() => undefined)
      await androidContext.clearCookies({ domain: 'localhost' }).catch(() => undefined)
      await androidPage.goto('about:blank').catch(() => undefined)
    }
  } finally {
    await senderContext?.clearCookies().catch(() => undefined)
    await senderContext?.close().catch(() => undefined)
    await browser?.close().catch(() => undefined)
    await androidBrowser?.close().catch(() => undefined)
  }
}
