import { expect, test } from '@playwright/test'

test.beforeEach(async ({ page }) => {
  await page.goto('/tests/password_reset_visibility/fixture.html')
})

test('one control reveals and hides the new password and confirmation together', async ({ page }) => {
  const password = page.getByRole('textbox', { name: 'Новый пароль', exact: true })
  const confirmation = page.getByRole('textbox', { name: 'Повторите пароль', exact: true })

  await expect(password).toHaveAttribute('type', 'password')
  await expect(confirmation).toHaveAttribute('type', 'password')
  await page.screenshot({ path: test.info().outputPath('password-reset-form.png'), fullPage: true })

  await password.fill('SyntheticPassword123!')
  await confirmation.fill('SyntheticPassword123!')
  const showButton = page.getByRole('button', { name: 'Показать пароли' })
  await expect(showButton).toHaveCount(1)

  await showButton.click()
  await expect(password).toHaveAttribute('type', 'text')
  await expect(confirmation).toHaveAttribute('type', 'text')
  const hideButton = page.getByRole('button', { name: 'Скрыть пароли' })
  await expect(hideButton).toHaveCount(1)
  await expect(hideButton).toHaveAttribute('aria-pressed', 'true')

  await hideButton.click()
  await expect(password).toHaveAttribute('type', 'password')
  await expect(confirmation).toHaveAttribute('type', 'password')
})
