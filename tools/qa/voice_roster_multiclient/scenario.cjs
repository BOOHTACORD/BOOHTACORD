// Real browser and LiveKit clients; only capture sources and accounts are synthetic.
const { chromium } = require('C:/b689/clients/web/node_modules/playwright')
const fs = require('node:fs')
const { roster } = require('./roster_evidence.cjs')
const { instrument, prepare, exercise } = require('../ws_media_independence/probe.cjs')
const microphone = require('../voice_roster_media/microphone.cjs'), audio = require('../voice_roster_media/audio.cjs')
const screen = require('../voice_roster_media/screen.cjs')
const privacy = require('../public_realtime_privacy/probe.cjs')
const input = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const result = { checks: {}, failed_stage: 'startup' }
const contexts = []
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
async function until(fn, message, timeout = 40000) {
  const deadline = Date.now() + timeout
  while (Date.now() < deadline) { if (await fn()) return; await sleep(200) }
  throw Error(message)
}
async function open(browser, login, password, register = false, injectFault = false) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, permissions: ['microphone'], viewport: { width: 1440, height: 900 } })
  contexts.push(context)
  await context.addInitScript(instrument)
  const page = await context.newPage(), sockets = [], requests = []
  const fault = injectFault ? await prepare(page) : null
  page.on('request', request => { try { requests.push(new URL(request.url()).pathname) } catch {} })
  page.on('websocket', socket => {
    const row = { path: new URL(socket.url()).pathname, open: true, roster: 0, dm: 0, session: 0 }
    sockets.push(row); socket.on('close', () => { row.open = false })
    socket.on('framereceived', frame => { try { const kind = JSON.parse(frame.payload).kind; if (kind === 'voice.roster.snapshot') row.roster++; if (kind === 'direct_message.message_created') row.dm++; if (kind === 'session.state_changed') row.session++ } catch {} })
  })
  for (let attempt = 0; ; attempt++) {
    try { await page.goto('https://localhost:4810/', { waitUntil: 'domcontentloaded', timeout: 5000 }); break }
    catch (error) {
      if (attempt >= 14 || !String(error).includes('ERR_CONNECTION_REFUSED')) throw error
      await sleep(1000)
    }
  }
  if (register) await page.getByRole('button', { name: 'Создать аккаунт', exact: true }).click()
  await page.getByLabel('Логин', { exact: true }).fill(login)
  await page.getByLabel('Пароль', { exact: true }).fill(password)
  await page.locator('.authentication-submit').click()
  await page.getByTestId('app-shell').waitFor({ timeout: 40000 })
  return { page, sockets, requests, fault }
}
async function room(page, name = 'QA voice') {
  await page.getByRole('button', { name: 'Каналы', exact: true }).click()
  await page.getByText(name, { exact: true }).first().click()
  await page.locator('.voice-prejoin').waitFor({ timeout: 30000 })
}
async function join(page, name = 'QA voice', microphone = false) {
  await room(page, name)
  await page.getByRole('button', { name: microphone ? 'Войти' : 'Без микрофона', exact: true }).click()
  await until(async () => (await page.getByTestId('voice-dock').locator('.voice-status').textContent()) === 'Голос подключён', 'voice not connected')
  await until(async () => (await page.getByTestId('voice-dock').locator('.voice-dock-subtitle').textContent())?.includes(name), 'voice channel mismatch')
}
async function capture(page, name) { await page.screenshot({ path: `${input.output}/${name}.png` }) }
async function main() {
  const browser = await chromium.launch({ headless: true, args: ['--allow-loopback-in-peer-connection', '--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'] })
  try {
    result.failed_stage = 'login'
    const observer = await open(browser, 'qa_admin', input.password)
    const first = await open(browser, 'qa_admin', input.password, false, true)
    const second = await open(browser, 'qa_roster', input.password, true)
    result.failed_stage = 'public_privacy_start'
    const publicProbe = await privacy.start(observer, until); await privacy.directMessage(second, observer, until)
    result.failed_stage = 'empty'
    await room(observer.page)
    await observer.page.getByText('Пока никого нет.', { exact: true }).waitFor({ timeout: 40000 })
    await roster(observer.page, [])
    result.checks.empty = true; await capture(observer.page, 'empty')
    result.failed_stage = 'first_join'
    await join(first.page, 'QA voice', true); await roster(observer.page, ['qa_admin'])
    result.checks.first_join = true; await capture(observer.page, 'first-join')
    result.failed_stage = 'second_join'
    await join(second.page); await roster(observer.page, ['qa_admin', 'qa_roster'])
    result.checks.second_join = true; await capture(observer.page, 'second-join')
    result.failed_stage = 'microphone'
    await microphone.exercise(first.page, observer.page, until, name => capture(observer.page, name))
    await audio.exercise(second.page, until, name => capture(second.page, name)); result.checks.microphone = true; result.checks.audio_receiving = true
    result.failed_stage = 'screen_share'
    await screen.exercise(first.page, observer.page, second.page, until, name => capture(observer.page, name), name => capture(second.page, name))
    result.checks.screen_share = true; result.checks.screen_receiving = true
    result.failed_stage = 'leave'
    await second.page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true }).click()
    await roster(observer.page, ['qa_admin'])
    result.checks.leave = true; await capture(observer.page, 'leave')
    result.failed_stage = 'rejoin'
    await join(second.page); await roster(observer.page, ['qa_admin', 'qa_roster'])
    result.checks.rejoin = true; await capture(observer.page, 'rejoin')
    result.failed_stage = 'transfer'
    await join(second.page, 'QA voice two'); await roster(observer.page, ['qa_admin'])
    await room(observer.page, 'QA voice two'); await roster(observer.page, ['qa_roster'], 'QA voice two')
    result.checks.transfer = true; await capture(observer.page, 'transfer')
    result.failed_stage = 'socket_guard'
    for (const client of [first, second]) {
      await until(() => client.page.evaluate(() => window.__qaPeers.some(peer => peer.connectionState === 'connected')), 'live transport not connected')
    }
    result.checks.live_transport = true
    for (const client of [observer, first, second]) {
      await until(() => client.sockets.filter(s => s.open && s.path === '/api/v1/realtime').length === 1, 'application socket count')
      if (client.sockets.some(s => s.open && s.path === '/api/v1/public/realtime') ||
          client.requests.some(path => ['/api/v1/voice/rosters/events', '/api/v1/maintenance/events'].includes(path))) throw Error('legacy or duplicate stream')
    }
    result.checks.socket_guard = true
    result.failed_stage = 'public_privacy'
    await privacy.revokeOthers(first, observer, until); await privacy.verify(publicProbe, observer, until)
    result.checks.public_privacy = true
    result.failed_stage = 'ws_independent'
    await exercise(first.page, first.fault, until, () => capture(first.page, 'ws-outage-media-connected'))
    result.checks.ws_independent = true; delete result.failed_stage
  } catch (error) {
    result.error_type = error.name
    result.error_summary = String(error.message).split('\n')[0].replaceAll(input.password, '[redacted]')
    process.exitCode = 1
  } finally {
    await Promise.all(contexts.map(context => context.close()))
    await browser.close()
    fs.writeFileSync(process.argv[3], JSON.stringify(result, null, 2) + '\n')
  }
}
main().catch(error => { result.error_type = error.name; fs.writeFileSync(process.argv[3], JSON.stringify(result)); process.exit(1) })
