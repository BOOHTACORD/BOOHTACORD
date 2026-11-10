const { allowed } = require('./event.cjs')
const dm = require('./dm.cjs')
const session = require('./session.cjs')

async function start(observer, until) {
  const page = await observer.page.context().newPage()
  await page.goto('https://localhost:4810/api/v1/health')
  const status = await page.evaluate(async () => (await fetch('/api/v1/auth/session', { credentials: 'same-origin' })).status)
  if (status !== 200) throw Error('authenticated cookie absent from public-socket fixture')
  const state = { ready: 0, snapshot: 0, invalid: 0 }
  page.on('websocket', socket => {
    if (new URL(socket.url()).pathname !== '/api/v1/public/realtime') { state.invalid++; return }
    socket.on('framereceived', frame => {
      try {
        const event = JSON.parse(frame.payload)
        if (!allowed(event)) state.invalid++
        else if (event.kind === 'connection.ready') state.ready++
        else if (event.kind === 'maintenance.snapshot') state.snapshot++
      } catch { state.invalid++ }
    })
  })
  const before = observer.sockets.reduce((sum, socket) => sum + socket.roster, 0)
  await page.evaluate(() => { window.__qaPublic = new WebSocket('wss://localhost:4810/api/v1/public/realtime') })
  await until(() => state.ready === 1 && state.snapshot === 1, 'public initial state missing')
  return { page, state, before }
}

async function verify(probe, observer, until) {
  await until(() => observer.sockets.reduce((sum, socket) => sum + socket.roster, 0) > probe.before,
    'authenticated roster change was not observed')
  await new Promise(resolve => setTimeout(resolve, 2000))
  if (probe.state.invalid !== 0 || !await probe.page.evaluate(() => window.__qaPublic.readyState === 1)) {
    throw Error('public socket leaked or closed')
  }
  await probe.page.close()
}

module.exports = { start, verify, directMessage: dm.exercise, revokeOthers: session.revokeOthers }
