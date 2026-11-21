import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { pathToFileURL } from 'node:url'
import { createInterface } from 'node:readline'

const repo = process.cwd()
const input = JSON.parse(fs.readFileSync(process.env.QA_PAIR_INPUT, 'utf8'))
process.env.QA_ORIGIN = input.origin
const require = createRequire(path.join(repo, 'clients/web/package.json'))
const { chromium, expect } = require('@playwright/test')
const { api, login, channel, status } = await import(pathToFileURL(path.join(repo, 'tools/qa/client_lifecycle/request.mjs')))
const { prepareOwnedLoopback } = await import(pathToFileURL(path.join(repo, 'tools/qa/client_lifecycle/loopback_navigation.mjs')))
const origin = input.origin
const receiverAccount = 'qa_rx_' + String(Date.now()).slice(-8)
const roomName = 'Issue785MicPair' + String(Date.now()).slice(-7)
let browser, adminContext, adminPage, receiverContext, receiverPage

async function installPeerObserver() {
  window.__qaPeers = []
  const Native = window.RTCPeerConnection
  window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
    const peer = Reflect.construct(target, args)
    window.__qaPeers.push(peer)
    return peer
  } })
}

async function receiverCounters() {
  return receiverPage.evaluate(async () => {
    const totals = {
      peer_connections: 0,
      active_peer_connections: 0,
      connected_peer_connections: 0,
      inbound_audio_tracks: 0,
      inbound_audio_packets: 0,
      inbound_audio_bytes: 0,
    }
    for (const peer of window.__qaPeers ?? []) {
      totals.peer_connections++
      if (peer.connectionState !== 'closed') totals.active_peer_connections++
      if (peer.connectionState === 'connected') totals.connected_peer_connections++
      if (peer.connectionState === 'closed') continue
      try {
        const stats = await peer.getStats()
        for (const report of stats.values()) {
          if (report.type === 'inbound-rtp' && (report.kind === 'audio' || report.mediaType === 'audio')) {
            totals.inbound_audio_tracks++
            totals.inbound_audio_packets += Number(report.packetsReceived ?? 0)
            totals.inbound_audio_bytes += Number(report.bytesReceived ?? 0)
          }
        }
      } catch { /* Ignore a peer that closes between state and stats reads. */ }
    }
    return totals
  })
}

try {
  browser = await chromium.launch({ headless: true, args: ['--allow-loopback-in-peer-connection'] })
  adminContext = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } })
  await adminContext.addInitScript(installPeerObserver)
  adminContext.setDefaultTimeout(15000)
  adminPage = await adminContext.newPage()
  await login(adminPage, 'qa_admin', input.password)

  const member = await api(adminPage, '/auth/register', 'POST', { login: receiverAccount, password: input.password })
  status(member, 201)
  const category = await api(adminPage, '/admin/categories', 'POST', { name: roomName })
  status(category, 201)
  const voice = await api(adminPage, `/admin/categories/${category.body.id}/channels`, 'POST', { name: roomName, kind: 'VOICE' })
  status(voice, 201)

  receiverContext = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } })
  await receiverContext.addInitScript(installPeerObserver)
  receiverContext.setDefaultTimeout(15000)
  receiverPage = await receiverContext.newPage()
  await prepareOwnedLoopback(receiverPage, origin)
  await login(receiverPage, receiverAccount, input.password)
  await expect(receiverPage.getByTestId('app-shell')).toBeVisible()
  await channel(receiverPage, roomName)
  const prejoin = receiverPage.locator('.voice-prejoin')
  await expect(prejoin).toBeVisible()
  await prejoin.getByRole('button', { name: 'Без микрофона', exact: true }).click()
  await expect(receiverPage.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })

  const beforeFlutter = await receiverCounters()
  fs.writeFileSync(process.env.QA_PAIR_READY, JSON.stringify({
    receiverAccount,
    channelId: voice.body.id,
    receiverBeforeFlutter: beforeFlutter,
  }))
  fs.chmodSync(process.env.QA_PAIR_READY, 0o600)
  console.log('PAIR_READY')

  const samples = []
  const sample = async () => {
    const counters = await receiverCounters()
    const observation = { observed_at_unix_ms: Date.now(), ...counters }
    samples.push(observation)
    if (process.env.QA_PAIR_PROGRESS) {
      const temporary = process.env.QA_PAIR_PROGRESS + '.tmp'
      fs.writeFileSync(temporary, JSON.stringify(observation), { mode: 0o600 })
      fs.renameSync(temporary, process.env.QA_PAIR_PROGRESS)
    }
  }
  let sampling = false
  const appendSample = async () => {
    if (sampling) return
    sampling = true
    try { await sample() } finally { sampling = false }
  }
  await appendSample()
  const timer = setInterval(() => { void appendSample() }, 2000)
  const commands = createInterface({ input: process.stdin, crlfDelay: Infinity })
  await new Promise((resolve, reject) => {
    commands.once('line', line => {
      commands.close()
      line === 'STOP' ? resolve() : reject(new Error('Unexpected runner command'))
    })
  })
  clearInterval(timer)
  await appendSample()
  const output = {
    receiver: 'Playwright Chromium listener-only participant',
    microphonePublishedByReceiver: false,
    samples,
    finalCounters: samples.at(-1),
  }
  fs.writeFileSync(process.env.QA_PAIR_FINAL, JSON.stringify(output, null, 2) + '\n', { mode: 0o600 })
  await receiverPage.evaluate(() => {
    for (const peer of window.__qaPeers ?? []) peer.close()
  }).catch(() => undefined)
  await receiverPage.close({ runBeforeUnload: false }).catch(() => undefined)
  await adminPage.close({ runBeforeUnload: false }).catch(() => undefined)
  await receiverContext.close().catch(() => undefined)
  await adminContext.close().catch(() => undefined)
  await browser.close().catch(() => undefined)
  browser = null
  console.log('PAIR_STOPPED samples=' + samples.length)
} catch (error) {
  console.error('PAIR_FAILED=' + String(error instanceof Error ? error.message : error).split(input.password).join('[redacted]'))
  process.exitCode = 1
} finally {
  if (browser) await browser.close().catch(() => undefined)
}

process.stdin.destroy()
process.exit(process.exitCode ?? 0)
