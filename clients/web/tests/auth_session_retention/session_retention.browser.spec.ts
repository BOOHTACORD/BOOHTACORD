import { expect, test, type Route } from '@playwright/test'

test('login stores a persistent secure cookie and restores the session after reload and browser restart', async ({ page, context, browser }) => {
  const expires = new Date(Date.now() + 180 * 24 * 60 * 60 * 1000)
  let authenticatedReads = 0

  await context.route('**/api/v1/auth/login', async route => {
    await route.fulfill({status: 204, headers: {
      'set-cookie': `vp_session=synthetic-session; Path=/; Max-Age=15552000; Expires=${expires.toUTCString()}; HttpOnly; Secure; SameSite=Lax`,
    }})
  })
  const routeSessionLookup = async (route: Route) => {
    const authenticated = route.request().headers().cookie?.includes('vp_session=synthetic-session') ?? false
    if (authenticated) authenticatedReads++
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(authenticated
        ? { authenticated: true, account_id: 'synthetic-account', role: 'MEMBER' }
        : { authenticated: false }),
    })
  }
  await context.route('**/api/v1/auth/session', routeSessionLookup)
  await page.goto('/tests/auth_session_retention/fixture.html')
  await expect(page.getByRole('status')).toHaveText('Гость')
  await page.getByRole('button', { name: 'Войти' }).click()
  await expect(page.getByRole('status')).toHaveText('Сессия сохранена')

  const cookie = (await context.cookies()).find(item => item.name === 'vp_session')
  expect(cookie).toBeDefined()
  expect(cookie?.httpOnly).toBe(true)
  expect(cookie?.secure).toBe(true)
  expect(cookie?.sameSite).toBe('Lax')
  expect(cookie?.expires).toBeGreaterThan(Date.now() / 1000)
  const readsBeforeReload = authenticatedReads

  await page.screenshot({ path: test.info().outputPath('persistent-session.png'), fullPage: true })
  await page.reload()
  await expect(page.getByRole('status')).toHaveText('Сессия сохранена')
  expect(authenticatedReads).toBeGreaterThan(readsBeforeReload)

  const browserState = await context.storageState()
  const restartedContext = await browser.newContext({ storageState: browserState })
  await restartedContext.route('**/api/v1/auth/session', routeSessionLookup)
  try {
    const restartedPage = await restartedContext.newPage()
    await restartedPage.goto('/tests/auth_session_retention/fixture.html')
    await expect(restartedPage.getByRole('status')).toHaveText('Сессия сохранена')
  } finally {
    await restartedContext.close()
  }
})
