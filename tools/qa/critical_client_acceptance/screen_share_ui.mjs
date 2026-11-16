import { miniPlayerInterface } from './mini_player_ui.mjs'
import { verifyScreenPreview } from './screen_preview_acceptance.mjs'
import assert from 'node:assert/strict'
import { expect } from '../client_lifecycle/request.mjs'
import { openViewerPanel, selectVisibleStream } from './select_stream.mjs'

// Only the OS-picker boundary is synthetic. Admission, publication, subscription,
// decoding and stop use the owned Go API/SFU and the production Web application.
export async function screenShareInterface(sender, receiver, input, report, subscriptions) {
  const descriptorResponses = []
  const telemetryResponses = []
  const descriptorResponse = response => {
    try {
      const url = new URL(response.url())
      if (url.origin === 'https://localhost:4810' && /\/api\/v1\/voice\/leases\/[^/]+\/screen-profile\/v1$/.test(url.pathname)) descriptorResponses.push(response.status())
      if (url.origin === 'https://localhost:4810' && /\/api\/v1\/voice\/leases\/[^/]+\/screen-telemetry$/.test(url.pathname)) telemetryResponses.push(response.status())
    } catch { /* Keep acceptance diagnostics bounded and content-free. */ }
  }
  sender.on('response', descriptorResponse)
  await sender.evaluate(() => {
    const original = navigator.mediaDevices.getDisplayMedia.bind(navigator.mediaDevices)
    window.__qaShareUI = { original, mode: 'cancel', captures: 0, activated: [], track: null, timer: null, sound: null, oscillator: null, stream: null }
    navigator.mediaDevices.getDisplayMedia = async () => {
      const state = window.__qaShareUI
      state.captures++; state.activated.push(navigator.userActivation.isActive)
      if (state.mode !== 'publish') throw new DOMException('Synthetic picker boundary', state.mode === 'cancel' ? 'AbortError' : 'NotAllowedError')
      const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 360
      const context = canvas.getContext('2d'); let n = 0
      const draw = () => { context.fillStyle = ++n % 2 ? '#163d62' : '#1d6144'; context.fillRect(0, 0, 640, 360); context.fillStyle = '#fff'; context.fillRect(n % 500, 80, 50, 50) }
      draw(); state.timer = setInterval(draw, 33)
      const stream = canvas.captureStream(30)
      state.sound = new AudioContext()
      const gain = state.sound.createGain(), destination = state.sound.createMediaStreamDestination()
      state.oscillator = state.sound.createOscillator(); state.oscillator.frequency.value = 440; gain.gain.value = .02
      state.oscillator.connect(gain).connect(destination); state.oscillator.start(); await state.sound.resume()
      destination.stream.getAudioTracks().forEach(track => stream.addTrack(track)); state.stream = stream
      state.track = stream.getVideoTracks()[0]
      return stream
    }
  })
  const dock = sender.getByTestId('voice-dock')
  const launch = async () => {
    await dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true }).click()
    const setup = sender.getByRole('dialog', { name: 'Демонстрация экрана', exact: true })
    await expect(setup.locator('.screen-share-capabilities__details')).not.toHaveAttribute('open', '')
    await expect(setup.getByText('Рекомендуемый профиль', { exact: true })).toHaveCount(0)
    await expect(setup.getByText(/Суммарный лимит двух слоёв/)).not.toBeVisible()
    await setup.getByRole('radio', { name: '720p' }).check()
    await setup.getByRole('radio', { name: '30 FPS', exact: true }).check()
    await setup.getByRole('button', { name: 'Начать трансляцию', exact: true }).click()
  }
  try {
    await launch()
    await expect(dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true })).toBeEnabled()
    await expect(receiver.getByTestId('stream-select')).toHaveCount(0)
    await sender.evaluate(() => { window.__qaShareUI.mode = 'denied' })
    await launch()
    await expect(sender.getByRole('alert').filter({ hasText: 'Браузер запретил захват экрана' }).first()).toBeVisible()
    await expect(receiver.getByTestId('stream-select')).toHaveCount(0)
    await sender.evaluate(() => { window.__qaShareUI.mode = 'publish' })
    await launch()
    await expect(dock.getByRole('button', { name: 'Остановить демонстрацию экрана', exact: true })).toBeEnabled({ timeout: 30000 })
    await expect.poll(() => sender.locator('video.screen-player').evaluate(video => video.videoWidth > 0 && video.getVideoPlaybackQuality().totalVideoFrames > 0), { timeout: 30000 }).toBe(true)
    console.log('stage=sender-screen-preview:decoded-frames')
    await sender.screenshot({ path: input.directory + '/screen-share-owner-preview.png' })
    await verifyScreenPreview(sender, receiver, input)
    await openViewerPanel(sender, 'participants')
    await expect(sender.getByRole('status', { name: 'Активные сеансы просмотра: 0. Это не подтверждение внимания.' })).toBeVisible()
    await selectVisibleStream(receiver)
    await expect.poll(() => receiver.locator('video.screen-player').evaluate(video => video.videoWidth > 0 && video.getVideoPlaybackQuality().totalVideoFrames > 0), { timeout: 30000 }).toBe(true)
    await openViewerPanel(receiver, 'participants')
    const receiverParticipants = receiver.getByTestId('viewer-participants')
    await expect(receiverParticipants.getByRole('status', { name: 'Активные сеансы просмотра: 1. Это не подтверждение внимания.' })).toBeVisible({ timeout: 15000 })
    await expect(receiverParticipants.getByRole('img', { name: 'Смотрит эту трансляцию' })).toHaveCount(1)
    const ownerParticipants = sender.getByTestId('viewer-participants')
    await expect(ownerParticipants.getByRole('status', { name: 'Активные сеансы просмотра: 1. Это не подтверждение внимания.' })).toBeVisible({ timeout: 15000 })
    await expect(ownerParticipants.getByRole('img', { name: 'Смотрит вашу трансляцию' })).toHaveCount(1)
    await receiver.locator('summary[aria-label="Статистика"]').click()
    const stats = receiver.getByRole('dialog', { name: 'Статистика трансляции' })
    await expect(stats.getByRole('heading', { name: 'У вас', exact: true })).toBeVisible()
    await expect(stats.getByRole('heading', { name: 'Отправитель', exact: true })).toBeVisible()
    await expect(stats.locator('.screen-diagnostics-target')).toHaveText('Цель: 720p · 30 FPS')
    await expect(stats.locator('.screen-diagnostics-summary')).toContainText('Видео у вас')
    const senderSummary = stats.locator('.screen-diagnostics-summary__group[aria-labelledby="screen-summary-sender"]')
    await expect.poll(() => senderSummary.innerText(), { timeout: 20000 }).toContain('Актуально')
    await expect(senderSummary).toContainText('640 × 360 пикс. · измерено')
    await expect(senderSummary).not.toContainText('Нет измерений от отправителя.')
    await expect.poll(() => receiver.evaluate(() => window.__qaScreenTelemetryCount ?? 0), { timeout: 20000 }).toBeGreaterThan(0)
    await expect.poll(() => descriptorResponses.includes(204), { timeout: 10000 }).toBe(true)
    await expect.poll(() => telemetryResponses.length, { timeout: 10000 }).toBeGreaterThan(0)
    assert.ok(telemetryResponses.every(status => status === 204), 'Every sender telemetry request must be accepted by the relay.')
    const events = await receiver.evaluate(() => window.__qaScreenTelemetryCount ?? 0)
    console.log('stage=screen-telemetry-pair-status:descriptor=' + descriptorResponses.join(',') + ';post=' + telemetryResponses.join(',') + ';events=' + events)
    console.log('stage=screen-share-sender-telemetry-received')
    await receiver.screenshot({ path: input.directory + '/screen-share-compact-statistics.png' })
    await stats.evaluate(panel => { panel.scrollTop = panel.scrollHeight })
    const technicalSummary = stats.locator('.stream-diagnostics-technical > summary')
    await technicalSummary.evaluate(node => node.scrollIntoView({ block: 'nearest', inline: 'nearest' }))
    const diagnosticsViewport = await technicalSummary.evaluate(node => {
      const panel = node.closest('.stream-diagnostics-panel')
      const rect = node.getBoundingClientRect()
      const panelRect = panel?.getBoundingClientRect()
      const style = panel ? getComputedStyle(panel) : null
      const trigger = document.querySelector('.stream-diagnostics > summary')
      const triggerRect = trigger?.getBoundingClientRect()
      return {
        top: Math.round(rect.top), bottom: Math.round(rect.bottom), viewportHeight: window.innerHeight,
        panelTop: panelRect ? Math.round(panelRect.top) : -1,
        panelBottom: panelRect ? Math.round(panelRect.bottom) : -1,
        panelInlineTop: panel?.style.top ?? '',
        panelInlineMaxHeight: panel?.style.maxHeight ?? '',
        panelComputedMaxHeight: style?.maxHeight ?? '',
        triggerTop: triggerRect ? Math.round(triggerRect.top) : -1,
        triggerBottom: triggerRect ? Math.round(triggerRect.bottom) : -1,
        scrollTop: panel ? Math.round(panel.scrollTop) : -1,
        scrollHeight: panel ? Math.round(panel.scrollHeight) : -1,
        clientHeight: panel ? Math.round(panel.clientHeight) : -1,
        overflowY: style?.overflowY ?? 'missing',
      }
    })
    console.log('stage=screen-diagnostics-viewport:' + JSON.stringify(diagnosticsViewport))
    await expect.poll(() => technicalSummary.evaluate(node => {
      const rect = node.getBoundingClientRect()
      return rect.top >= 0 && rect.bottom <= window.innerHeight
    })).toBe(true)
    await technicalSummary.click()
    await expect(stats.locator('.stream-diagnostics-technical')).toHaveAttribute('open', '')
    const confirmation = await stats.locator('.screen-diagnostics-details section[aria-labelledby="screen-diagnostics-config"] dl > div').filter({ hasText: 'Состояние публикации' }).locator('dd').innerText()
    assert.ok(['Конфигурация передана отправителем', 'Обновление конфигурации ожидается', 'Нет подтверждения от отправителя'].includes(confirmation))
    console.log('stage=screen-configuration-status:' + confirmation)
    await expect(stats.locator('.screen-diagnostics-details section[aria-labelledby="screen-diagnostics-receiver"] h3')).toHaveText('Приёмник')
    await receiver.keyboard.press('Escape')
    await expect(stats).toHaveCount(0)
    await miniPlayerInterface(sender, receiver, input, report, subscriptions)
    console.log('stage=screen-share-mini-player-returned')
    await sender.bringToFront()
    await sender.locator('.screen-stage').hover()
    console.log('stage=screen-share-owner-controls-revealed')
    await sender.getByRole('button', { name: 'Остановить свою трансляцию', exact: true }).click()
    console.log('stage=screen-share-owner-stop-accepted')
    await expect(dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true })).toBeEnabled()
    await expect(receiver.getByTestId('stream-select')).toHaveCount(0, { timeout: 15000 })
    await expect(receiver.getByTestId('participant-screen-preview')).toHaveCount(0, { timeout: 15000 })
    console.log('stage=screen-share-view-removed')
    await expect.poll(() => sender.evaluate(() => window.__qaShareUI.track.readyState)).toBe('ended')
    console.log('stage=screen-share-owner-track-ended')
    const observation = await sender.evaluate(() => ({ captures: window.__qaShareUI.captures, activated: window.__qaShareUI.activated }))
    assert.equal(observation.captures, 3); assert.deepEqual(observation.activated, [true, true, true])
    for (const page of [sender, receiver]) await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
    report.screen_share_interface = { boundary: 'synthetic canvas and quiet oscillator; OS picker NOT_RUN', actual_api_sfu: true, cancel_without_publication: true, permission_denied_visible: true, owner_preview_decoded: true, listener_participant_card_thumbnail_visible: true, owner_stopped_from_viewer: true, receiver_view_decoded: true, owner_and_viewer_audience_visible: true, ended_source_track: true, voice_retained: true, selected_configuration_measured_separate: true, configuration_observed: confirmation, diagnostics_optional: true, ...observation, media_quality: 'NOT_RUN' }
  } finally {
    sender.off('response', descriptorResponse)
    await sender.evaluate(() => {
      const state = window.__qaShareUI
      navigator.mediaDevices.getDisplayMedia = state.original
      clearInterval(state.timer); state.stream?.getTracks().forEach(track => track.stop()); state.oscillator?.stop(); void state.sound?.close()
      delete window.__qaShareUI
    })
  }
}
