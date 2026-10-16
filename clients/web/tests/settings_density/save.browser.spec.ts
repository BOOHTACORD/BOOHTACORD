import { expect, test } from '@playwright/test'
import { routes } from '../microcopy/routes'

test('role pending and conflict feedback stays visible and retains the draft', async ({ page }, info) => {
  await page.setViewportSize({ width: 390, height: 900 })
  await routes(page)
  let release!: () => void
  const pending = new Promise<void>(resolve => { release = resolve })
  await page.route('**/api/v1/admin/roles/MEMBER/permissions', async route => {
    await pending
    await route.fulfill({ status: 409, json: { error: { code: 'CONFLICT', message: 'Настройки уже изменены другим администратором.' } } })
  })
  await page.goto('/tests/microcopy/fixture.html?surface=admin&section=roles')
  const checkbox = page.getByRole('checkbox', { name: 'Создавать текстовые каналы', exact: true })
  await checkbox.uncheck()
  const save = page.getByRole('button', { name: 'Сохранить', exact: true })
  await save.click()
  await expect(save).toBeDisabled()
  await expect(page.getByRole('status').filter({ hasText: 'Сохраняем…' })).toBeVisible()
  await page.screenshot({ path: info.outputPath('role-pending.png') })
  release()
  await expect(page.getByRole('alert')).toContainText('Черновик сохранён')
  await expect(checkbox).not.toBeChecked()
  await expect(page.getByText('Настройки уже изменены', { exact: false }).first()).toBeVisible()
  await page.screenshot({ path: info.outputPath('role-conflict.png') })
})
