import assert from 'node:assert/strict'
import { api, expect, openNavigation } from './request.mjs'

// Owned disposable accounts and actual Go API. Never emits credentials or payloads.
export async function personalSettings(page, input, report) {
  const original = (await api(page, '/me')).body
  await openNavigation(page)
  await page.getByRole('button', { name: 'Открыть настройки профиля', exact: true }).click()
  const name = page.getByRole('textbox', { name: 'Отображаемое имя', exact: true })
  const save = page.getByRole('button', { name: 'Сохранить профиль', exact: true })
  const cancel = page.getByRole('button', { name: 'Отменить', exact: true })
  await expect(save).toBeDisabled()
  await name.fill('Synthetic discarded name'); await cancel.click()
  await expect(name).toHaveValue(original.display_name)
  assert.equal((await api(page, '/me')).body.display_name, original.display_name)
  await name.fill('Synthetic settings check'); await save.click()
  await expect(page.getByRole('status').filter({ hasText: 'Имя профиля сохранено.' })).toBeVisible()
  assert.equal((await api(page, '/me')).body.display_name, 'Synthetic settings check')
  await page.screenshot({ path: input.directory + '/settings-profile-saved.png' })
  await name.fill(original.display_name); await save.click()
  await expect(page.getByRole('status').filter({ hasText: 'Имя профиля сохранено.' })).toBeVisible()
  await expect(name).toHaveValue(original.display_name)
  assert.equal((await api(page, '/me')).body.display_name, original.display_name)
  await page.getByRole('tab', { name: 'Безопасность', exact: true }).click()
  await page.getByLabel('Новый пароль', { exact: true }).fill('SyntheticDiscardedOnly')
  await page.getByRole('button', { name: 'Отменить', exact: true }).click()
  await expect(page.getByLabel('Новый пароль', { exact: true })).toHaveValue('')
  await expect(page.getByRole('button', { name: 'Обновить пароль', exact: true })).toBeDisabled()
  await page.screenshot({ path: input.directory + '/settings-security-cancelled.png' })
  await page.getByRole('tab', { name: 'Уведомления', exact: true }).click()
  await expect(page.getByText('Текст личных сообщений в уведомлениях не показывается.', { exact: true })).toBeVisible()
  await page.screenshot({ path: input.directory + '/settings-notifications.png' })
  await page.getByRole('button', { name: 'Закрыть настройки', exact: true }).click()
  report.settings_hierarchy = { actual_profile_cancel_without_write: true, explicit_save_and_restore_confirmed_by_api: true,
    password_cancel_clears_draft: true, notification_privacy_visible: true }
  console.log('stage=settings-personal-api-accepted')
}

// The caller captures and verifies RTCPeerConnection identity before/after this navigation.
export async function liveAudioSettings(page, input, report) {
  await openNavigation(page)
  await page.getByRole('button', { name: 'Настройки аудио', exact: true }).click()
  const advanced = page.locator('.audio-advanced'), summary = advanced.locator(':scope > summary')
  await expect(advanced).not.toHaveAttribute('open', '')
  await expect(page.getByRole('button', { name: 'Обновить устройства', exact: true })).toHaveCSS('opacity', '1')
  await page.screenshot({ path: input.directory + '/settings-audio-basic.png' })
  await summary.click()
  const echo = page.getByRole('switch', { name: /Подавление эха/ }), gain = page.getByRole('slider', { name: /Громкость микрофона/ })
  const echoValue = await echo.isChecked(), gainValue = await gain.inputValue()
  await summary.click(); await summary.click()
  assert.equal(await echo.isChecked(), echoValue)
  await expect(gain).toHaveValue(gainValue)
  await echo.scrollIntoViewIfNeeded()
  await expect(echo).toBeInViewport()
  await page.screenshot({ path: input.directory + '/settings-audio-advanced.png' })
  await page.getByRole('button', { name: 'Закрыть настройки аудио', exact: true }).click()
  Object.assign(report.settings_hierarchy, { advanced_keeps_control_values: true, actual_voice_settings_navigation: true, actual_advanced_controls_in_viewport: true })
  console.log('stage=settings-live-audio-accepted')
}
