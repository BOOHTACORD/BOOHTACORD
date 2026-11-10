function applicationSocket(url) {
  return url.protocol === 'wss:' && url.host === 'localhost:4810' &&
    !url.username && !url.password && url.pathname === '/api/v1/realtime'
}

function handle(route, state) {
  if (state.blocked) { state.attempts++; route.close(); return }
  state.bridges.push({ route, server: route.connectToServer() })
}

module.exports = { applicationSocket, handle }
