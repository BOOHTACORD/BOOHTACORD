import { expect, test } from '@playwright/test'

test.beforeEach(async ({ page }) => {
  await page.goto('/tests/password_reset_visibility/fixture.html')
})

test('new password and confirmation can be revealed independently', async ({ page }) => {
  const password = page.getByRole('textbox', { name: 'Новый пароль', exact: true })
  const confirmation = page.getByRole('textbox', { name: 'Повторите пароль', exact: true })

  await expect(password).toHaveAttribute('type', 'password')
  await expect(confirmation).toHaveAttribute('type', 'password')
  await page.screenshot({ path: test.info().outputPath('password-reset-form.png'), fullPage: true })

  await password.fill('SyntheticPassword123!')
  await confirmation.fill('SyntheticPassword123!')
  const showButtons = page.getByRole('button', { name: 'Показать пароль' })
  await expect(showButtons).toHaveCount(2)

  await showButtons.nth(0).click()
  await expect(password).toHaveAttribute('type', 'text')
  await expect(page.getByRole('button', { name: 'Скрыть пароль' }).nth(0)).toHaveAttribute('aria-pressed', 'true')
  await expect(confirmation).toHaveAttribute('type', 'password')

  await page.getByRole('button', { name: 'Показать пароль' }).click()
  await expect(confirmation).toHaveAttribute('type', 'text')
  await expect(page.getByRole('button', { name: 'Скрыть пароль' })).toHaveCount(2)

  await page.getByRole('button', { name: 'Скрыть пароль' }).nth(0).click()
  await expect(password).toHaveAttribute('type', 'password')
  await expect(confirmation).toHaveAttribute('type', 'text')
})
