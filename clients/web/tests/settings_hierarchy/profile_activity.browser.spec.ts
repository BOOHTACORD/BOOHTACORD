import { expect, test } from '@playwright/test'
import { open } from './hierarchy_helpers'

test('profile cancellation remains clickable at tablet size with system activity settings', async ({ page }, info) => {
  await page.setViewportSize({ width: 1024, height: 768 })
  await page.addInitScript(() => {
    Object.defineProperty(window, 'IdleDetector', { value: class { static async requestPermission() { return 'granted' } } })
  })
  await open(page, 'profile&systemActivity=1')
  await page.locator('.workspace-main-panel').evaluate((panel) => {
    Object.assign((panel as HTMLElement).style, { height: '540px', minHeight: '0' })
  })
  await expect(page.getByRole('heading', { name: 'Активность компьютера' })).toBeVisible()
  const name = page.getByRole('textbox', { name: 'Отображаемое имя', exact: true })
  await name.fill('Черновик')
  await page.screenshot({ path: info.outputPath('profile-activity-1024.png') })
  await page.getByRole('button', { name: 'Отменить', exact: true }).click({ timeout: 5000 })
  await expect(name).toHaveValue('Тестовый участник')
})
