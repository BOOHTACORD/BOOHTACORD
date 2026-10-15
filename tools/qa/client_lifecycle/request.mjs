import { createRequire } from 'node:module'
import assert from 'node:assert/strict'
import { withLoginDiagnostics } from './login_diagnostics.mjs'
const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
export const { chromium, expect } = require('@playwright/test')
export const origin = process.env.QA_ORIGIN
export async function api(page, path, method = 'GET', body) {
  return page.evaluate(async ({ path, method, body }) => {
    const response = await fetch('/api/v1'+path, {
      method, credentials: 'same-origin', headers: { 'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    })
    return { status: response.status, body: response.status === 204 ? null : await response.json() }
  }, { path, method, body })
}
export function status(result, expected) { assert.equal(result.status, expected) }
export async function login(page, loginName, password, diagnosticsDirectory) {
  const perform = async () => {
    await page.goto(origin)
    await page.getByLabel('Логин', { exact: true }).fill(loginName)
    await page.getByLabel('Пароль', { exact: true }).fill(password)
    await page.getByRole('button', { name: 'Войти', exact: true }).click()
    await expect(page.getByTestId('app-shell')).toBeVisible()
  }
  return diagnosticsDirectory ? withLoginDiagnostics(page, diagnosticsDirectory, perform) : perform()
}
export async function openNavigation(page) {
  const scrim = page.locator('.drawer-scrim')
  if (await scrim.isVisible()) {
    const viewport = page.viewportSize() ?? { width: 320, height: 600 }
    const navigationOpen = await page.locator('.sidebar').evaluate(element => element.classList.contains('is-open'))
    await scrim.click({ position: {
      x: navigationOpen ? viewport.width - 8 : 8,
      y: Math.max(8, Math.min(viewport.height / 2, viewport.height - 8)),
    } })
    await expect(scrim).toBeHidden()
  }
  const guildHeader = page.locator('.guild-header')
  if (!(await guildHeader.isVisible())) {
    const viewport = page.viewportSize() ?? { width: 320, height: 600 }
    if (viewport.width >= 1024) {
      await expect(guildHeader).toBeVisible()
    } else {
      await page.getByRole('button', { name: 'Открыть навигацию', exact: true }).click()
      await expect(guildHeader).toBeVisible()
    }
  }
}
export async function channel(page, channelName = 'WelcomeLab') {
  const target = page.locator('.channel-button').filter({ hasText: channelName })
  await openNavigation(page)
  await expect(target).toBeVisible()
  await target.click()
}
export async function guildPanel(page) {
  await openNavigation(page)
  await page.locator('.guild-header').click()
  await page.getByRole('navigation', { name: 'Разделы администрирования' })
    .getByRole('button', { name: 'Гильдия', exact: true }).click()
}
export async function security(page) {
  await openNavigation(page)
  await page.getByRole('button', { name: 'Открыть настройки профиля', exact: true }).click()
  await page.getByRole('tab', { name: 'Безопасность', exact: true }).click()
}
