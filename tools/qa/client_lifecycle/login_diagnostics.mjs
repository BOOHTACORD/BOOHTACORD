import { join } from 'node:path'

// Observe only the owned fixture's HTTP status and fixed UI booleans. Never
// retain a URL, cookie, credential, response body or editable field contents.
export async function withLoginDiagnostics(page, directory, action,
  log = value => console.error('login-diagnostics='+JSON.stringify(value))) {
  const statuses = { login_status: null, session_status: null,
    login_transport_error: null, session_transport_error: null }
  function endpoint(value) {
    let url
    try { url = new URL(value.url()) } catch { return }
    if (url.origin !== 'https://localhost:4810' || url.username || url.password) return
    return url.pathname === '/api/v1/auth/login' ? 'login'
      : url.pathname === '/api/v1/auth/session' ? 'session' : null
  }
  function response(value) {
    const key = endpoint(value)
    if (!key) return
    const status = value.status()
    if (Number.isInteger(status) && status >= 100 && status <= 599) statuses[key+'_status'] = status
  }
  function requestFailed(value) {
    const key = endpoint(value)
    if (!key) return
    const known = {
      'net::ERR_NETWORK_CHANGED': 'network_changed',
      'net::ERR_CONNECTION_RESET': 'connection_reset',
      'net::ERR_CONNECTION_CLOSED': 'connection_closed',
      'net::ERR_CONNECTION_REFUSED': 'connection_refused',
      'net::ERR_HTTP2_PROTOCOL_ERROR': 'http2_protocol',
      'net::ERR_CERT_AUTHORITY_INVALID': 'certificate',
      'net::ERR_ABORTED': 'aborted',
    }
    statuses[key+'_transport_error'] = known[value.failure()?.errorText] ?? 'other'
  }
  page.on('response', response)
  page.on('requestfailed', requestFailed)
  try { return await action() }
  catch (error) {
    try {
      log({ ...statuses,
        workspace_present: await page.getByTestId('app-shell').count() > 0,
        form_error_present: await page.locator('#authentication-error').count() > 0,
        session_screen_present: await page.locator('.session-state').count() > 0,
      })
    } catch { /* Preserve the original assertion if the page has closed. */ }
    try {
      await page.screenshot({ path: join(directory, 'login-failure.png'),
        mask: [page.locator('input, textarea')], timeout: 5000 })
    } catch { /* Diagnostic capture cannot change an acceptance result. */ }
    throw error
  } finally {
    page.off('response', response)
    page.off('requestfailed', requestFailed)
  }
}
