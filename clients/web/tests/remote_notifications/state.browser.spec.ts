import { expect, test } from '@playwright/test'
import { expectAxeClear } from '../accessibility/axe'
test('settings support keyboard account consent without a device prompt and pass axe', async ({ page }) => {
  await page.setViewportSize({ width: 393, height: 1100 })
  await page.addInitScript(() => {
    ;(window as any).notificationPermissionCalls = 0
    Notification.requestPermission = async () => { (window as any).notificationPermissionCalls++; return 'denied' }
  })
  await page.goto('/tests/remote_notifications/fixture.html')
  const account = page.getByLabel('Разрешить фоновые уведомления для аккаунта')
  await account.focus(); await page.keyboard.press('Space'); await expect(account).toBeChecked()
  expect(await page.evaluate(() => (window as any).notificationPermissionCalls)).toBe(0)
  await expectAxeClear(page)
})
test('transactional dedup survives pages, account changes and stale callbacks', async ({ context, page }) => {
  await page.goto('/tests/remote_notifications/fixture.html'); await page.addScriptTag({ url: '/notification-state.js' })
  const second = await context.newPage(); await second.goto('/tests/remote_notifications/fixture.html'); await second.addScriptTag({ url: '/notification-state.js' })
  const state = { scope: 'origin/installation/account-a', binding: 'binding-a', generation: 1, active: true }
  expect(await page.evaluate(async state => (window as any).notificationState.set(0, state), state)).toMatchObject({ ok: true, record: { epoch: 1 } })
  const claims = await Promise.all([page, second].map(p => p.evaluate(async () => (window as any).notificationState.claim('origin/installation/account-a', 'ref-1', Date.now() + 60000, 1))))
  expect(claims.filter(c => c.duplicate === false)).toHaveLength(1); expect(claims.filter(c => c.duplicate === true)).toHaveLength(1)
  expect(await second.evaluate(async () => (window as any).notificationState.set(1, { scope: 'origin/installation/account-b', binding: 'binding-b', generation: 2, active: true }))).toMatchObject({ ok: true, record: { epoch: 2 } })
  expect(await page.evaluate(async () => (window as any).notificationState.clearScope('origin/installation/account-a', 1))).toEqual({ ok: false })
  expect(await page.evaluate(async () => (window as any).notificationState.claim('origin/installation/account-a', 'ref-2', Date.now() + 60000, 1))).toEqual({ ok: false })
  await second.evaluate(async () => { const state = (window as any).notificationState; for (let i = 0; i < 520; i++) await state.claim('origin/installation/account-b', `ref-${i}`, Date.now() + 60000, 2) })
  const count = await page.evaluate(() => new Promise<number>(resolve => { const req = indexedDB.open('boohtacord-notifications-v1', 1); req.onsuccess = () => { const r = req.result.transaction('seen').objectStore('seen').count(); r.onsuccess = () => { resolve(r.result); req.result.close() } } }))
  expect(count).toBe(512)
  expect(await page.evaluate(async () => (window as any).notificationState.read())).toMatchObject({ scope: 'origin/installation/account-b', epoch: 2 })
  expect(await second.evaluate(async () => (window as any).notificationState.clearScope('origin/installation/account-b', 2))).toMatchObject({ ok: true })
  expect(await page.evaluate(async () => (window as any).notificationState.set(3, { scope: 'account-c', active: true }))).toEqual({ ok: false })
  expect(await page.evaluate(async () => (window as any).notificationState.claim('origin/installation/account-b', 'after-logout', Date.now() + 60000, 2))).toEqual({ ok: false })
})
for (const width of [1440, 393]) test(`account and device controls are separate at ${width}px`, async ({ page }) => {
  await page.setViewportSize({ width, height: 1100 }); await page.goto('/tests/remote_notifications/fixture.html')
  await expect(page.getByLabel('Разрешить фоновые уведомления для аккаунта')).not.toBeChecked()
  await expect(page.getByRole('button', { name: 'Включить на этом устройстве' })).toBeDisabled()
  await page.getByText('Перенести явные локальные настройки').click()
  await expect(page.getByText('Локальные уведомления были выключены.', { exact: false })).toBeVisible()
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: `../../.out/notify554/browser/settings-${width}.png`, fullPage: true })
})
