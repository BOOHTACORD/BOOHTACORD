import { createRequire } from 'node:module'
const require = createRequire(new URL('../../../../clients/web/package.json', import.meta.url))
const { SignalRequest } = require('@livekit/protocol')

export async function observeMiniSubscriptions(page) {
  const counts = { subscribe: 0, unsubscribe: 0 }
  await page.routeWebSocket(url => new URL(url).pathname.startsWith('/qa-sfu'), socket => {
    const server = socket.connectToServer()
    socket.onMessage(data => {
      try {
        const request = typeof data === 'string' ? SignalRequest.fromJsonString(data) : SignalRequest.fromBinary(data)
        const subscription = request.message?.case === 'subscription' ? request.message.value : request.subscription
        if (subscription) counts[subscription.subscribe ? 'subscribe' : 'unsubscribe'] += subscription.trackSids?.length || subscription.participantTracks?.reduce((n, p) => n + (p.trackSids?.length || 0), 0) || 0
      } catch { /* Forward every frame unchanged; retain counts only. */ }
      server.send(data)
    })
    server.onMessage(data => socket.send(data))
  })
  return () => ({ ...counts })
}
