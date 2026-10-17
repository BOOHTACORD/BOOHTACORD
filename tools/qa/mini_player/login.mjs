import assert from 'node:assert/strict'
import { expect } from '../client_lifecycle/request.mjs'

// This legacy runner owns a separate stack on 4830; the 4810 lifecycle login
// deliberately rejects it. Never enter disposable credentials on another origin.
export async function login(page, name, password) {
  const origin = process.env.QA_ORIGIN
  assert.equal(origin, 'https://localhost:4830')
  const response = await page.goto(origin + '/api/v1/health')
  assert.equal(response.status(), 200)
  assert.equal(response.url(), origin + '/api/v1/health')
  await page.goto(origin)
  await page.getByLabel('Логин', { exact: true }).fill(name)
  await page.getByLabel('Пароль', { exact: true }).fill(password)
  await page.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect(page.getByTestId('app-shell')).toBeVisible()
}
