import { join } from 'node:path'

// Observe only the owned fixture's HTTP status and fixed UI booleans. Never
// retain a URL, cookie, credential, response body or editable field contents.
export async function withLoginDiagnostics(page, directory, action,
  log = value => console.error('login-diagnostics='+JSON.stringify(value))) {
  const statuses = { login_status: null, session_status: null }
  function response(value) {
    let url
    try { url = new URL(value.url()) } catch { return }
    if (url.origin !== 'https://localhost:4810' || url.username || url.password) return
    const key = url.pathname === '/api/v1/auth/login' ? 'login_status'
      : url.pathname === '/api/v1/auth/session' ? 'session_status' : null
    if (!key) return
    const status = value.status()
    if (Number.isInteger(status) && status >= 100 && status <= 599) statuses[key] = status
  }
  page.on('response', response)
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
  } finally { page.off('response', response) }
}
