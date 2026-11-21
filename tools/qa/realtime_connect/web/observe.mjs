// Retain actual sockets and finite counters only; never retain payloads or URLs.
export function observe() {
  const Native = window.WebSocket
  window.__r2 = { socket: null, constructed: 0, ready: false, closed: 0,
    guest: { socket:null, constructed:0, ready:false, closed:0 } }
  window.WebSocket = new Proxy(Native, { construct(target, args, newTarget) {
    const socket = Reflect.construct(target, args, newTarget)
    const path = new URL(args[0], location.href).pathname
    if (!['/api/v1/realtime','/api/v1/public/realtime'].includes(path)) return socket
    const subject = path === '/api/v1/realtime' ? window.__r2 : window.__r2.guest
    subject.socket = socket; subject.constructed++; subject.ready = false
    socket.addEventListener('close', () => { subject.closed++ })
    socket.addEventListener('message', message => {
      try {
        if (subject.socket === socket && JSON.parse(message.data).kind ===
          (subject === window.__r2 ? 'connection.ready' : 'maintenance.snapshot')) {
          subject.ready = true
        }
      } catch { /* No payload or parser diagnostic is retained. */ }
    })
    return socket
  } })
}

export function control(page, token, mode) {
  return page.evaluate(async ({ token, mode }) => {
    const response = await fetch('/qa-r2/control', { method: mode ? 'POST' : 'GET',
      credentials: 'omit', headers: { authorization: 'Bearer '+token, 'content-type': 'application/json' },
      ...(mode ? { body: JSON.stringify({ mode }) } : {}) })
    if (!response.ok) throw Error('Owned R2 control failed')
    return response.json()
  }, { token, mode })
}
