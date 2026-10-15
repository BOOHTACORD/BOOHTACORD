// Retain no URLs, headers, cookies, response bodies or raw browser error text.
export function observeRosterNetwork(page) {
  const result = { status: null, failed: {} }
  const reasons = new Map([
    ['net::ERR_HTTP2_PROTOCOL_ERROR', 'http2_protocol'],
    ['net::ERR_CONNECTION_CLOSED', 'closed'],
    ['net::ERR_CONNECTION_RESET', 'reset'],
    ['net::ERR_ABORTED', 'aborted'],
    ['net::ERR_NETWORK_CHANGED', 'network_changed'],
    ['net::ERR_TIMED_OUT', 'timeout'],
    ['net::ERR_CONTENT_LENGTH_MISMATCH', 'length_mismatch'],
  ])
  function owned(value) {
    try {
      const url = new URL(value)
      return url.origin === 'https://localhost:4810' && !url.username && !url.password &&
        url.pathname === '/api/v1/voice/rosters/events'
    } catch { return false }
  }
  page.on('response', response => {
    if (!owned(response.url())) return
    const status = response.status()
    if (Number.isInteger(status) && status >= 100 && status <= 599) result.status = status
  })
  page.on('requestfailed', request => {
    if (!owned(request.url())) return
    const reason = reasons.get(request.failure()?.errorText) ?? 'other'
    result.failed[reason] = (result.failed[reason] ?? 0) + 1
  })
  return () => ({ status: result.status, failed: { ...result.failed } })
}
