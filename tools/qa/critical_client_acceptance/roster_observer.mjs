// Observe control counters only; never retain roster payloads or identities.
export function installRosterFailureObserver(browser = window) {
  const Native = browser.WebSocket
  browser.__qaRosterUnavailableCount = 0
  browser.__qaRosterTransport = { created: 0, opened: 0, failed: 0, closed_by_client: 0, latest_closed_by_client: false }
  browser.__qaRosterTransportSource = null
  browser.WebSocket = new Proxy(Native, { construct(target, args, newTarget) {
    const socket = Reflect.construct(target, args, newTarget)
    let owned = false
    try {
      const url = new URL(args[0], browser.location.href)
      owned = url.host === browser.location.host && !url.username && !url.password &&
        (url.protocol === 'ws:' || url.protocol === 'wss:') && url.pathname === '/api/v1/realtime'
    } catch { /* Invalid constructors remain the native implementation's responsibility. */ }
    if (!owned) return socket
    browser.__qaRosterTransport.created++
    browser.__qaRosterTransport.latest_closed_by_client = false
    browser.__qaRosterTransportSource = socket
    const close = socket.close
    socket.close = function (...closeArgs) {
      browser.__qaRosterTransport.closed_by_client++
      if (browser.__qaRosterTransportSource === socket) browser.__qaRosterTransport.latest_closed_by_client = true
      return Reflect.apply(close, this, closeArgs)
    }
    socket.addEventListener('open', () => { browser.__qaRosterTransport.opened++ })
    socket.addEventListener('error', () => { browser.__qaRosterTransport.failed++ })
    socket.addEventListener('message', event => {
      try {
        if (typeof event.data === 'string' && JSON.parse(event.data)?.kind === 'voice.roster.unavailable') {
          browser.__qaRosterUnavailableCount++
        }
      } catch { /* Malformed frames do not become a successful observation. */ }
    })
    return socket
  } })
}
