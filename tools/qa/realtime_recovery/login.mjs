import assert from 'node:assert/strict'
import { expect, origin } from '../client_lifecycle/request.mjs'

export async function login(page, name, password) {
  assert.equal(origin, 'https://localhost:4910')
  // Settle readonly renderer navigation before submitting disposable credentials once.
  for (let attempt = 0; attempt < 3; attempt++) {
    try { await page.goto(origin); break }
    catch (error) {
      if (attempt === 2 || !String(error).includes('net::ERR_NETWORK_CHANGED')) throw error
    }
  }
  await page.getByLabel('Логин', { exact: true }).fill(name)
  await page.getByLabel('Пароль', { exact: true }).fill(password)
  await page.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect(page.getByTestId('app-shell')).toBeVisible()
}
