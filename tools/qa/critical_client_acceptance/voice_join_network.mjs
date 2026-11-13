// Record only bounded categories: never retain URLs, identifiers, tokens or bodies.
const failures = new Map([
  ['net::ERR_TIMED_OUT', 'timeout'],
  ['net::ERR_CONNECTION_CLOSED', 'closed'],
  ['net::ERR_CONNECTION_RESET', 'reset'],
  ['net::ERR_CONNECTION_REFUSED', 'refused'],
  ['net::ERR_NETWORK_CHANGED', 'network_changed'],
  ['net::ERR_ABORTED', 'aborted'],
])

function stage(request) {
  try {
    const url = new URL(request.url())
    if (url.origin !== 'https://localhost:4810' || url.username || url.password) return null
    const method = request.method()
    if (method === 'POST' && /^\/api\/v1\/voice\/channels\/[^/]+\/leases$/.test(url.pathname)) return 'lease'
    if (method === 'POST' && /^\/api\/v1\/voice\/leases\/[^/]+\/credential$/.test(url.pathname)) return 'credential'
    if (method === 'DELETE' && /^\/api\/v1\/voice\/leases\/[^/]+$/.test(url.pathname)) return 'release'
  } catch { /* Ignore non-HTTP and malformed requests. */ }
  return null
}

export function classifyVoiceJoinAlert(value) {
  if (!value) return 'none'
  const text = String(value).toLowerCase()
  if (/timeout|timed out|превышено время/.test(text)) return 'timeout'
  if (/голосовой запрос отклонён/.test(text)) return 'admission'
  if (/webrtc|peerconnection|peer connection|\bice\b/.test(text)) return 'media'
  return 'other'
}

export function observeVoiceJoinNetwork(page) {
  const events = []
  const record = event => { if (events.length < 20) events.push(event) }
  const response = item => {
    try {
      const category = stage(item.request())
      if (!category) return
      const status = item.status()
      if (Number.isInteger(status) && status >= 100 && status <= 599) record({ stage: category, status })
    } catch { /* Diagnostics must never interrupt the test. */ }
  }
  const failed = request => {
    try {
      const category = stage(request)
      if (category) record({ stage: category, failure: failures.get(request.failure()?.errorText) ?? 'other' })
    } catch { /* Diagnostics must never interrupt the test. */ }
  }
  page.on('response', response)
  page.on('requestfailed', failed)
  return {
    snapshot: () => events.map(event => ({ ...event })),
    close: () => { page.off('response', response); page.off('requestfailed', failed) },
  }
}

export async function withVoiceJoinDiagnostics(page, action, emit = value => console.error('voice-join-diagnostics=' + JSON.stringify(value))) {
  let observer
  try { observer = observeVoiceJoinNetwork(page) } catch { /* The actual join remains authoritative. */ }
  try {
    return await action()
  } catch (error) {
    const diagnostic = { network: observer?.snapshot() ?? [], alert: 'unavailable', peer_states: [] }
    try {
      const alerts = await page.getByTestId('voice-dock').locator('[role=alert]').allTextContents()
      diagnostic.alert = classifyVoiceJoinAlert(alerts.join(' ').slice(0, 1024))
    } catch { /* A closed page is a valid diagnostic limitation. */ }
    try {
      const states = await page.evaluate(() => (window.__qaPeers || []).slice(-20).map(peer => peer.connectionState))
      const allowed = new Set(['new', 'connecting', 'connected', 'disconnected', 'failed', 'closed'])
      if (Array.isArray(states)) diagnostic.peer_states = states.slice(-20).map(state => allowed.has(state) ? state : 'other')
    } catch { /* Preserve the original join failure. */ }
    try { emit(diagnostic) } catch { /* Diagnostics must not replace the failure. */ }
    throw error
  } finally {
    try { observer?.close() } catch { /* Cleanup must not replace the result. */ }
  }
}
