import assert from 'node:assert/strict'
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
const origin = input.origin
const account = 'qa_rx_' + String(Date.now()).slice(-8)
const roomName = 'Issue785FlutterPair' + String(Date.now()).slice(-7)
let browser
let senderPage

async function audioCounters(page) {
  return page.evaluate(async () => {
    const totals = { peerConnections: 0, activePeerConnections: 0, outboundAudioPackets: 0, outboundAudioBytes: 0 }
    for (const peer of window.__qaPeers ?? []) {
      totals.peerConnections++
      if (peer.connectionState !== 'closed') totals.activePeerConnections++
      if (peer.connectionState === 'closed') continue
      try {
        const stats = await peer.getStats()
        for (const report of stats.values()) {
          if (report.type === 'outbound-rtp' && (report.kind === 'audio' || report.mediaType === 'audio')) {
            totals.outboundAudioPackets += Number(report.packetsSent ?? 0)
            totals.outboundAudioBytes += Number(report.bytesSent ?? 0)
          }
        }
      } catch { /* Ignore a peer that closes between state and stats reads. */ }
    }
    return totals
  })
}

try {
  browser = await chromium.launch({ headless: true, args: [
    '--allow-loopback-in-peer-connection', '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream',
    '--use-file-for-fake-audio-capture=' + process.env.QA_AUDIO_WAV,
  ] })
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } })
  await context.grantPermissions(['microphone'], { origin })
  await context.addInitScript(() => {
    window.__qaPeers = []
    const Native = window.RTCPeerConnection
    window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
      const peer = Reflect.construct(target, args)
      window.__qaPeers.push(peer)
      return peer
    } })
  })
  context.setDefaultTimeout(15000)
  senderPage = await context.newPage()
  await login(senderPage, 'qa_admin', input.password)

  const member = await api(senderPage, '/auth/register', 'POST', { login: account, password: input.password })
  status(member, 201)
  const category = await api(senderPage, '/admin/categories', 'POST', { name: roomName })
  status(category, 201)
  const voice = await api(senderPage, `/admin/categories/${category.body.id}/channels`, 'POST', { name: roomName, kind: 'VOICE' })
  status(voice, 201)
  await senderPage.reload()
  await expect(senderPage.getByTestId('app-shell')).toBeVisible()
  await channel(senderPage, roomName)
  const prejoin = senderPage.locator('.voice-prejoin')
  await expect(prejoin).toBeVisible()
  await prejoin.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect(senderPage.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })
  await expect.poll(async () => (await audioCounters(senderPage)).outboundAudioBytes, { timeout: 20000 }).toBeGreaterThan(0)

  const senderInitial = await audioCounters(senderPage)
  fs.writeFileSync(process.env.QA_PAIR_READY, JSON.stringify({ account, channelId: voice.body.id, senderInitial }))
  fs.chmodSync(process.env.QA_PAIR_READY, 0o600)
  console.log('PAIR_READY')

  const commands = createInterface({ input: process.stdin, crlfDelay: Infinity })
  await new Promise((resolve, reject) => {
    commands.once('line', line => {
      commands.close()
      line === 'STOP' ? resolve() : reject(new Error('Unexpected runner command'))
    })
  })
  const senderFinal = await audioCounters(senderPage)
  const output = {
    sender: 'Playwright Chromium synthetic microphone',
    outboundAudioCounters: senderFinal,
    activePeerConnections: senderFinal.activePeerConnections,
  }
  fs.writeFileSync(process.env.QA_PAIR_FINAL, JSON.stringify(output, null, 2) + '\n')
  console.log('SENDER_FINAL=' + JSON.stringify(output))
  console.log('PAIR_STOPPED')
} catch (error) {
  console.error('PAIR_FAILED=' + String(error instanceof Error ? error.message : error).split(input.password).join('[redacted]'))
  process.exitCode = 1
} finally {
  if (browser) await browser.close().catch(() => undefined)
}
