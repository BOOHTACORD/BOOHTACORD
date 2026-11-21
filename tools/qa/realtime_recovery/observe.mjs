// Observe only counters and retain the actual socket for owned fault injection.
export function observe(browser = window) {
  const Native = browser.WebSocket
  browser.__r1 = { opened: 0, socket: null, populated: 0, empty: 0, resync: 0, forceResync: false, generation: null }
  browser.WebSocket = new Proxy(Native, { construct(target, args, newTarget) {
    const url = new URL(args[0], browser.location.href)
    const owned = url.origin === browser.location.origin.replace('https:', 'wss:') && url.pathname === '/api/v1/realtime'
    if (owned && browser.__r1.forceResync) {
      url.searchParams.set('after', browser.crypto.randomUUID())
      args = [url.toString(), ...args.slice(1)]; browser.__r1.forceResync = false
    }
    const socket = Reflect.construct(target, args, newTarget)
    if (!owned) return socket
    browser.__r1.socket = socket
    socket.addEventListener('open', () => { browser.__r1.opened++ })
    socket.addEventListener('message', message => {
      try {
        const event = JSON.parse(message.data)
        if (event.kind === 'connection.resync_required') browser.__r1.resync++
        if (!['voice.roster.snapshot', 'voice.roster.snapshot.v2'].includes(event.kind)) return
        browser.__r1.generation = event.payload.generation
        const count = event.payload.channels.reduce((sum, room) => sum + room.participants.length, 0)
        browser.__r1[count ? 'populated' : 'empty']++
      } catch { /* No payload, URL, identity, credential or error text is retained. */ }
    })
    return socket
  } })
}
