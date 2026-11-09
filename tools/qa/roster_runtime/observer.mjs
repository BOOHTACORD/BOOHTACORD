// Inspect only the owned synthetic fixture's authenticated application socket.
export function installObserver(browser = window) {
  const Native = browser.WebSocket
  const q = browser.__qaRoster = { constructed: 0, active: 0, maxActive: 0, snapshots: 0, unavailable: 0, expired: 0, counts: [], lastEvent: null }
  let current = null
  browser.WebSocket = new Proxy(Native, { construct(target, args, newTarget) {
    const socket = Reflect.construct(target, args, newTarget)
    let owned = false
    try {
      const url = new URL(args[0], browser.location.href)
      owned = url.host === browser.location.host && !url.username && !url.password &&
        (url.protocol === 'ws:' || url.protocol === 'wss:') && url.pathname === '/api/v1/realtime'
    } catch { /* Native constructor retains validation responsibility. */ }
    if (!owned) return socket
    current = socket
    q.constructed++
    q.active++
    q.maxActive = Math.max(q.maxActive, q.active)
    let closed = false
    socket.addEventListener('close', event => {
      if (!closed) { closed = true; q.active-- }
      if (socket === current && event.code === 1008) q.expired++
    })
    socket.addEventListener('error', () => { if (socket === current) q.lastEvent = 'error' })
    socket.addEventListener('message', event => {
      if (socket !== current || typeof event.data !== 'string') return
      try {
        const value = JSON.parse(event.data)
        if (value.kind === 'voice.roster.unavailable') { q.unavailable++; q.lastEvent = 'unavailable'; return }
        if (value.kind !== 'voice.roster.snapshot' || !Array.isArray(value.payload?.channels)) return
        q.counts = value.payload.channels.map(c => ({ id: c.channel_id, count: c.participants.length,
          muted: c.participants.filter(p => p.microphone_muted).length, sharing: c.participants.filter(p => p.screen_sharing).length }))
        q.snapshots++
        q.lastEvent = 'snapshot'
      } catch { /* Invalid frames cannot prove a successful snapshot. */ }
    })
    return socket
  } })
}
