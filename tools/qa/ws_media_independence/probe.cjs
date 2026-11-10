const { applicationSocket, handle } = require('./route.cjs')

function instrument() {
  window.__qaPeers = []; window.__qaAppSockets = []
  const Peer = window.RTCPeerConnection, Socket = window.WebSocket
  window.RTCPeerConnection = new Proxy(Peer, { construct(target, args) {
    const peer = Reflect.construct(target, args); window.__qaPeers.push(peer); return peer
  } })
  window.WebSocket = new Proxy(Socket, { construct(target, args) {
    const socket = Reflect.construct(target, args)
    const url = new URL(args[0], window.location.href)
    if (url.host === window.location.host && url.pathname === '/api/v1/realtime') {
      socket.__qaReady = false; window.__qaAppSockets.push(socket)
      socket.addEventListener('message', event => {
        try { if (JSON.parse(event.data).kind === 'connection.ready') socket.__qaReady = true } catch {}
      })
    }
    return socket
  } })
}

async function prepare(page) {
  const state = { blocked: false, attempts: 0, bridges: [] }
  await page.routeWebSocket(applicationSocket, route => handle(route, state))
  return state
}

async function exercise(page, state, until, screenshot) {
  const prepared = await page.evaluate(() => {
    window.__qaPinnedPeers = window.__qaPeers.filter(peer => peer.connectionState === 'connected')
    window.__qaPriorSocket = window.__qaAppSockets.find(socket => socket.readyState === 1 && socket.__qaReady)
    return window.__qaPinnedPeers.length > 0 && Boolean(window.__qaPriorSocket)
  })
  if (!prepared || state.bridges.length !== 1) throw Error('live media or application socket unavailable')
  state.blocked = true
  const bridge = state.bridges[0]
  bridge.server.close(); bridge.route.close()
  await until(() => state.attempts > 0, 'application socket fault did not occur')
  const deadline = Date.now() + 4000
  while (Date.now() < deadline) {
    const live = await page.evaluate(() => window.__qaPinnedPeers.every(peer => peer.connectionState === 'connected'))
    if (!live) throw Error('media connection failed during application socket outage')
    await new Promise(resolve => setTimeout(resolve, 200))
  }
  await screenshot()
  state.blocked = false
  await until(() => page.evaluate(() => window.__qaAppSockets.some(socket =>
    socket !== window.__qaPriorSocket && socket.readyState === 1 && socket.__qaReady)), 'application socket did not recover')
  const live = await page.evaluate(() => window.__qaPinnedPeers.every(peer => peer.connectionState === 'connected'))
  if (!live) throw Error('media connection changed after application socket recovery')
}

module.exports = { instrument, prepare, exercise }
