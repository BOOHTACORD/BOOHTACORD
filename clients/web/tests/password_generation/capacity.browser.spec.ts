import { test, expect } from '@playwright/test'

test('busy login retains editable masked fields and only retries on a new user action', async ({ page }) => {
  let requests = 0
  await page.route('**/api/v1/auth/login', async route => {
    requests++
    await route.fulfill({ status: 503, headers: { 'retry-after': '7' }, contentType: 'application/json',
      body: JSON.stringify({ error: { code: 'AUTH_BUSY', message: 'Сервер занят.' } }) })
  })
  await page.goto('/tests/password_generation/fixture.html')
  await page.getByLabel('Логин').fill('synthetic-user')
  const password = page.getByLabel('Пароль', { exact: true })
  await password.fill('synthetic password')
  await page.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('вручную через 7 с.')
  await expect(password).toHaveValue('synthetic password')
  await expect(password).toHaveAttribute('type', 'password')
  await expect(password).toBeEditable()
  await expect(page.getByRole('button', { name: 'Войти', exact: true })).toBeEnabled()
  expect(requests).toBe(1)
  expect(await page.evaluate(() => localStorage.length + sessionStorage.length)).toBe(0)
  await page.screenshot({ path: test.info().outputPath('auth-capacity.png'), fullPage: true })
  await page.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect.poll(() => requests).toBe(2)
})

test('rate limited login retains editable masked fields and only retries on a new user action', async ({ page }) => {
  let requests = 0
  await page.route('**/api/v1/auth/login', async route => {
    requests++
    await route.fulfill({ status: 429, headers: { 'retry-after': '30' }, contentType: 'application/json',
      body: JSON.stringify({ error: { code: 'RATE_LIMITED', message: 'Слишком много попыток; повторите позже' } }) })
  })
  await page.goto('/tests/password_generation/fixture.html')
  await page.getByLabel('Логин').fill('synthetic-user')
  const password = page.getByLabel('Пароль', { exact: true })
  await password.fill('synthetic password')
  await page.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('вручную через 30 с.')
  await expect(password).toHaveValue('synthetic password')
  await expect(password).toHaveAttribute('type', 'password')
  await expect(password).toBeEditable()
  await expect(page.getByRole('button', { name: 'Войти', exact: true })).toBeEnabled()
  expect(requests).toBe(1)
  expect(await page.evaluate(() => localStorage.length + sessionStorage.length)).toBe(0)
  await page.screenshot({ path: test.info().outputPath('auth-rate-limit.png'), fullPage: true })
  await page.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect.poll(() => requests).toBe(2)
})
