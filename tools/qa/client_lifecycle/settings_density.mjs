import { api, channel, expect, openNavigation } from './request.mjs'
import assert from 'node:assert/strict'

export async function settingsDensity(page, input, report) {
  await openNavigation(page)
  await page.getByRole('button', { name: 'Настройки аудио', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Настройки аудио', exact: true })).toBeVisible()
  const advanced = page.locator('.audio-advanced')
  await expect(advanced).not.toHaveAttribute('open')
  await expect(page.getByRole('button', { name: 'Обновить устройства', exact: true })).toHaveCSS('opacity', '1')
  await page.screenshot({ path: input.directory + '/settings-audio-basic.png' })
  await advanced.locator('> summary').click()
  const echo = page.getByRole('switch', { name: 'Подавление эха', exact: true })
  const previous = await echo.isChecked()
  await echo.setChecked(!previous)
  await expect(echo).toBeChecked({ checked: !previous })
  await echo.setChecked(previous)
  await expect(echo).toBeChecked({ checked: previous })
  await page.screenshot({ path: input.directory + '/settings-audio-advanced.png' })
  await page.getByRole('button', { name: 'Закрыть настройки аудио', exact: true }).click()
  await channel(page, 'Text')
  await expect(page.getByRole('log', { name: 'История сообщений' })).toBeVisible()

  const original = (await api(page, '/me')).body.display_name
  await openNavigation(page)
  await page.getByRole('button', { name: 'Открыть настройки профиля', exact: true }).click()
  const name = page.getByLabel('Отображаемое имя', { exact: true })
  await name.fill('Проверка настроек')
  const save = page.getByRole('button', { name: 'Сохранить профиль', exact: true })
  await expect(page.getByRole('status').filter({ hasText: 'Есть несохранённые изменения' })).toBeVisible()
  await save.click()
  await expect(page.getByRole('status').filter({ hasText: 'Имя профиля сохранено.' })).toBeVisible()
  await page.screenshot({ path: input.directory + '/settings-profile-saved.png' })
  await name.fill(original)
  await save.click()
  await expect(page.getByRole('status').filter({ hasText: 'Имя профиля сохранено.' })).toBeVisible()
  await page.getByRole('button', { name: 'Закрыть настройки', exact: true }).click()
  await channel(page, 'Text')
  report.settings_density = { actual_authenticated_api: true, advanced_disclosure: true,
    processing_roundtrip: true, profile_explicit_save: true, synthetic_name_restored: true,
    return_to_text: true, hardware_audio: 'NOT_RUN' }
}

export async function activeVoiceSettings(page, input, report) {
  await page.evaluate(() => { window.__qaSettingsPeers = window.__qaPeers.filter(peer => peer.connectionState === 'connected') })
  await openNavigation(page)
  await page.getByRole('button', { name: 'Настройки аудио', exact: true }).click()
  await page.locator('.audio-advanced > summary').click()
  await expect(page.getByRole('switch', { name: 'Подавление эха', exact: true })).toBeVisible()
  await page.screenshot({ path: input.directory + '/settings-active-voice.png' })
  await page.getByRole('button', { name: 'Закрыть настройки аудио', exact: true }).click()
  await channel(page, 'VoiceLab')
  assert.equal(await page.evaluate(() => window.__qaSettingsPeers.length > 0 &&
    window.__qaSettingsPeers.every(peer => window.__qaPeers.includes(peer) && peer.connectionState === 'connected') &&
    window.__qaPeers.filter(peer => peer.connectionState === 'connected').length === window.__qaSettingsPeers.length), true)
  report.settings_density.active_voice_same_transports = true
}
