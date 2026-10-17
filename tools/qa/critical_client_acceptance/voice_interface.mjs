import assert from 'node:assert/strict'
import { voiceHeaderSearch } from '../client_lifecycle/header_actions.mjs'
import { liveAudioSettings } from '../client_lifecycle/settings_hierarchy.mjs'
import { channel, expect } from '../client_lifecycle/request.mjs'

// Actual owned API/SFU sessions; media quality and hardware capture are separate gates.
export async function voiceInterface(page, input, report) {
  const dock = page.getByTestId('voice-dock')
  const room = page.locator('.room-wrap')
  await expect(room.getByTestId('participant-card')).toHaveCount(2, { timeout: 15000 })
  await expect(room.getByRole('status')).toHaveText('Режим слушателя')
  await page.screenshot({ path: input.directory + '/voice-connected-compact.png' })
  await room.getByRole('button', { name: 'Выключить удалённый звук', exact: true }).click()
  await expect(room.getByRole('button', { name: 'Включить удалённый звук', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await expect(room.getByRole('button', { name: 'Включить микрофон', exact: true })).toBeDisabled()
  await page.screenshot({ path: input.directory + '/voice-deafened-compact.png' })
  await room.getByRole('button', { name: 'Включить удалённый звук', exact: true }).click()
  await expect(room.getByRole('button', { name: 'Выключить удалённый звук', exact: true })).toHaveAttribute('aria-pressed', 'false')
  await room.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true }).click()
  const setup = page.getByRole('dialog', { name: 'Демонстрация экрана', exact: true })
  await expect(setup).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(setup).toHaveCount(0)
  await expect(room.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true })).toBeFocused()
  assert.equal(await page.evaluate(() => window.__qaCaptureRequests), 0)
  await page.evaluate(() => { window.__qaVoicePeers = window.__qaPeers.filter(peer => peer.connectionState === 'connected') })
  const checkTransport = async () => {
    assert.equal(await page.evaluate(() => window.__qaVoicePeers.length > 0 && window.__qaVoicePeers.every(peer => window.__qaPeers.includes(peer) && peer.connectionState === 'connected') && window.__qaPeers.filter(peer => peer.connectionState === 'connected').length === window.__qaVoicePeers.length), true)
  }
  await voiceHeaderSearch(page, input, report)
  await checkTransport()
  Object.assign(report.header_actions.VOICE, { same_voice_transport:true })
  await liveAudioSettings(page, input, report)
  await checkTransport()
  Object.assign(report.settings_hierarchy, { same_voice_transport_after_settings: true })
  await channel(page, 'Text')
  await checkTransport()
  await expect(dock.locator('.voice-actions button')).toHaveCount(4)
  for (const button of await dock.locator('.voice-actions button').all()) await expect(button).toBeVisible()
  await dock.getByRole('button', { name: 'Выключить удалённый звук', exact: true }).click()
  await expect(dock.getByRole('button', { name: 'Включить удалённый звук', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await dock.getByRole('button', { name: 'Включить удалённый звук', exact: true }).click()
  await checkTransport()
  await expect(dock.locator('.voice-status')).toHaveText('Голос подключён')
  await page.screenshot({ path: input.directory + '/voice-text-navigation.png' })
  await page.setViewportSize({ width: input.viewport.width < 1024 ? 740 : 1000, height: input.viewport.height })
  await checkTransport()
  await page.setViewportSize({ width: input.viewport.width, height: input.viewport.height })
  await channel(page, 'VoiceLab')
  await checkTransport()
  await expect(room.getByTestId('participant-card')).toHaveCount(2)
  report.voice_interface = { actual_two_listener_sessions: true, compact_primary_controls: true, deafen_state: true,
    share_dialog_cancel_without_capture: true, focus_return: true, text_drawer_resize_retains_same_transport: true, all_four_mobile_dock_actions_without_drawer: true,
    hardware_capture_or_audio_quality: 'NOT_RUN' }
}

export async function leaveVoiceInterface(page, input, report) {
  const started = performance.now()
  await page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true }).click()
  await expect(page.locator('.participant-volume, .participant-watch, .members-voice-roster, .screen-viewer')).toHaveCount(0, { timeout: 2000 })
  const elapsed = Math.round(performance.now() - started)
  await expect(page.getByRole('button', { name: 'Без микрофона', exact: true })).toBeVisible()
  const closeNavigation = page.getByTestId('nav-sidebar').getByRole('button', { name: 'Закрыть навигацию', exact: true })
  if (await closeNavigation.count()) await closeNavigation.click()
  await expect(closeNavigation).toHaveCount(0)
  await page.mouse.move(-2, -2)
  await expect(page.getByRole('tooltip')).toHaveCount(0)
  await page.screenshot({ path: input.directory + '/voice-after-leave.png' })
  Object.assign(report.voice_interface, { post_leave_interactive_roster_or_streams: 0, cleanup_observed_within_ms: elapsed,
    observation: 'Bounded live transition; no persistent old-roster defect inferred from the original tour frame.' })
}
