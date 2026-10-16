import assert from 'node:assert/strict'
import { api, expect, origin } from '../client_lifecycle/request.mjs'
import { withLoginDiagnostics } from '../client_lifecycle/login_diagnostics.mjs'
export async function registration(browser, input, report) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: input.width, height: 900 } })
  context.setDefaultTimeout(15000)
  try {
    const page = await context.newPage()
    let registrations = 0
    page.on('request', request => { if (new URL(request.url()).pathname === '/api/v1/auth/register') registrations++ })
    return await withLoginDiagnostics(page, input.directory, async () => {
      await page.goto(origin)
      await page.getByRole('button', { name: 'Как восстановить доступ' }).click()
      await expect(page.locator('.authentication-recovery-details')).toContainText('администратора')
      await page.getByRole('button', { name: 'Создать аккаунт', exact: true }).click()
      await page.getByLabel('Логин', { exact: true }).fill('qa_flow')
      const password = input.password+' é🙂е́ '
      await page.getByLabel('Пароль', { exact: true }).fill(password)
      const toggle = page.getByRole('button', { name: 'Показать пароль', exact: true })
      await toggle.click()
      await expect(page.getByLabel('Пароль', { exact: true })).toHaveAttribute('type', 'text')
      await expect(page.getByRole('button', { name: 'Скрыть пароль', exact: true })).toHaveAttribute('aria-pressed', 'true')
      await page.getByRole('button', { name: 'Скрыть пароль', exact: true }).click()
      await page.route('**/api/v1/auth/login', route => route.abort('internetdisconnected'))
      const registrationResponse = page.waitForResponse(response =>
        response.request().method() === 'POST' && new URL(response.url()).pathname === '/api/v1/auth/register',
        { timeout: 15000 })
      await page.locator('.authentication-submit').click()
      assert.equal((await registrationResponse).status(), 201)
      await expect(page.locator('.authentication-hint[role="status"]')).toContainText('Аккаунт создан', { timeout: 15000 })
      await expect(page.locator('.authentication-submit')).toHaveText('Войти')
      await expect(page.getByLabel('Пароль', { exact: true })).toHaveValue(password)
      await page.screenshot({ path: input.directory+'/registration-login-failed.png' })
      await page.unroute('**/api/v1/auth/login')
      await page.locator('.authentication-submit').click()
      await expect(page.getByTestId('app-shell')).toBeVisible()
      assert.equal(registrations, 1)
      report.authentication = { register_success_login_network_failure: true, manual_login_only: true,
        registrations, unicode_password_unchanged: true, show_password_accessible: true, admin_reset_explained: true }
      return (await api(page, '/auth/session')).body
    })
  } finally { await context.close() }
}
export async function rateLimit(browser, admin, input, report) {
  for (let index = 0; index < 12; index++) {
    const result = await api(admin, '/auth/login', 'POST', { login: 'qa_absent', password: input.password })
    if (result.status === 429) break
    assert.equal(result.status, 401)
  }
  const context = await browser.newContext({ ignoreHTTPSErrors: true })
  context.setDefaultTimeout(15000)
  try {
    const page = await context.newPage()
    let count = 0, retryAfter = null
    page.on('response', response => {
      if (new URL(response.url()).pathname === '/api/v1/auth/login') { count++; retryAfter = response.headers()['retry-after'] }
    })
    await page.goto(origin)
    await page.getByLabel('Логин', { exact: true }).fill('qa_absent')
    await page.getByLabel('Пароль', { exact: true }).fill(input.password)
    await page.locator('.authentication-submit').click()
    await expect(page.getByRole('alert')).toContainText('Повторите вручную')
    await page.waitForTimeout(300)
    assert.equal(count, 1)
    assert.match(retryAfter, /^\d+$/)
    await page.screenshot({ path: input.directory+'/authentication-rate-limit.png' })
    report.authentication.rate_limit = { actual_429: true, manual_retry_only: true, requests: count, retry_after_seconds: Number(retryAfter) }
  } finally { await context.close() }
}
