import { expect, test } from '@playwright/test'
import { routes } from '../microcopy/routes'
import { expectAxeClear } from '../accessibility/axe'

test.beforeEach(async ({ page }) => { await routes(page) })

for (const width of [390, 1024, 1440]) {
  test(`audio basics and advanced settings at ${width}px`, async ({ page }, info) => {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/tests/settings_density/fixture.html')
    await page.screenshot({ path: info.outputPath('audio-basic.png') })
    const advanced = page.locator('.audio-advanced')
    await expect(advanced).not.toHaveAttribute('open')
    await expect(page.getByRole('button', { name: 'Обновить устройства', exact: true })).toHaveCSS('opacity', '1')
    await expect(page.getByRole('switch', { name: 'Шумоподавление', exact: true })).toBeHidden()
    await page.getByRole('button', { name: 'По нажатию', exact: true }).press('Enter')
    await page.getByRole('button', { name: 'Назначить PTT-клавишу', exact: true }).click()
    await page.keyboard.press('KeyV')
    await expect(page.getByRole('button', { name: 'PTT: KeyV', exact: true })).toBeVisible()
    await advanced.locator('> summary').focus(); await page.keyboard.press('Enter')
    const noise = page.getByRole('switch', { name: 'Шумоподавление', exact: true })
    await noise.click(); await expect(noise).toHaveAttribute('aria-checked', 'false')
    await advanced.locator('> summary').click(); await advanced.locator('> summary').click()
    await expect(noise).toHaveAttribute('aria-checked', 'false')
    await page.screenshot({ path: info.outputPath('audio-advanced.png') })
    await expectAxeClear(page)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  })
}

for (const phase of ['denied', 'processing-error']) {
  test(`${phase} stays visible with advanced settings closed`, async ({ page }) => {
    await page.goto(`/tests/settings_density/fixture.html?phase=${phase}`)
    await expect(page.getByRole('alert')).toContainText(phase === 'denied' ? 'Нет доступа' : 'Отправка звука выключена')
    await expect(page.locator('.audio-advanced')).not.toHaveAttribute('open')
  })
}

for (const width of [390, 1024, 1440]) {
  for (const section of ['guild', 'members', 'roles', 'channels', 'audit', 'media', 'readiness', 'profile', 'security', 'notifications']) {
    test(`settings surface ${section} at ${width}px`, async ({ page }, info) => {
      await page.setViewportSize({ width, height: 900 })
      const profile = ['profile', 'security', 'notifications'].includes(section)
      await page.goto(`/tests/microcopy/fixture.html?surface=${profile ? 'profile' : 'admin'}&section=${section}`)
      if (section === 'security') {
        await page.getByRole('tab', { name: 'Безопасность', exact: true }).click()
        await expect(page.getByText('Обновляем сеансы…', { exact: true })).toBeHidden()
      }
      if (section === 'notifications') await page.getByRole('tab', { name: 'Уведомления', exact: true }).click()
      await page.screenshot({ path: info.outputPath(section + '.png') })
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
      if (section === 'roles') {
        await page.getByRole('checkbox', { name: 'Создавать текстовые каналы', exact: true }).first().uncheck()
        await expect(page.getByRole('status').filter({ hasText: 'Есть несохранённые изменения' })).toBeVisible()
        await expect(page.getByRole('button', { name: 'По умолчанию', exact: true })).toHaveCSS('opacity', '1')
        await page.screenshot({ path: info.outputPath('roles-dirty.png') })
      }
      if (section === 'readiness') {
        await expect(page.getByText('Сервисы готовы', { exact: true })).toBeVisible()
        await expect(page.getByRole('heading', { name: 'Синтетический пользовательский прогон' })).toBeHidden()
        await page.getByText('Диагностика готовности', { exact: true }).click()
        await expect(page.getByRole('heading', { name: 'Синтетический пользовательский прогон' })).toBeVisible()
      }
    })
  }
}
