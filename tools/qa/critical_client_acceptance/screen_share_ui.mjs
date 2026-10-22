import { miniPlayerInterface } from './mini_player_ui.mjs'
import assert from 'node:assert/strict'
import { expect } from '../client_lifecycle/request.mjs'
import { openViewerPanel, selectVisibleStream } from './select_stream.mjs'

// Only the OS-picker boundary is synthetic. Admission, publication, subscription,
// decoding and stop use the owned Go API/SFU and the production Web application.
export async function screenShareInterface(sender, receiver, input, report, subscriptions) {
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
    const ownerViewport = sender.viewportSize()
    assert.ok(ownerViewport)
    // Keep the owner's preview active while validating playback through a short resize.
    await sender.bringToFront()
    const framesBeforeShortViewport = await sender.locator('video.screen-player').evaluate(video => video.getVideoPlaybackQuality().totalVideoFrames)
    await sender.setViewportSize({ width: ownerViewport.width, height: 208 })
    const shortStage = await sender.locator('.screen-stage').evaluate(stage => {
      const rect = stage.getBoundingClientRect(), dock = document.querySelector('.mobile-voice-dock')
      const dockStyle = dock ? getComputedStyle(dock) : null
      const dockRect = dock && dockStyle?.display !== 'none' ? dock.getBoundingClientRect() : null
      const dockCoversStage = Boolean(dockRect && rect.right > dockRect.left && rect.left < dockRect.right)
      const visibleTop = Math.max(0, rect.top), visibleBottom = Math.min(innerHeight, rect.bottom, dockCoversStage ? dockRect.top : innerHeight)
      return { height: rect.height, visibleHeight: Math.max(0, visibleBottom - visibleTop), dockHeight: dockRect?.height ?? 0, dockPosition: dockStyle?.position ?? 'missing', dockGridColumns: dockStyle?.gridTemplateColumns ?? 'missing', dockCoversStage }
    })
    console.log('stage=screen-share-short-height:' + JSON.stringify(shortStage))
    assert.ok(shortStage.height >= 160 && shortStage.visibleHeight >= 80, JSON.stringify(shortStage))
    await expect.poll(() => sender.locator('video.screen-player').evaluate(video => video.getVideoPlaybackQuality().totalVideoFrames), { timeout: 5000 }).toBeGreaterThan(framesBeforeShortViewport)
    await sender.screenshot({ path: input.directory + '/screen-share-owner-preview-short-height.png' })
    await sender.setViewportSize(ownerViewport)
    await openViewerPanel(sender, 'participants')
    await expect(sender.getByRole('status', { name: 'Зрители трансляции: 0' })).toBeVisible()
    await selectVisibleStream(receiver)
    await expect.poll(() => receiver.locator('video.screen-player').evaluate(video => video.videoWidth > 0 && video.getVideoPlaybackQuality().totalVideoFrames > 0), { timeout: 30000 }).toBe(true)
    await openViewerPanel(receiver, 'participants')
    const receiverParticipants = receiver.getByTestId('viewer-participants')
    await expect(receiverParticipants.getByRole('status', { name: 'Зрители трансляции: 1' })).toBeVisible({ timeout: 15000 })
    await expect(receiverParticipants.getByRole('img', { name: 'Смотрит эту трансляцию' })).toHaveCount(1)
    const ownerParticipants = sender.getByTestId('viewer-participants')
    await expect(ownerParticipants.getByRole('status', { name: 'Зрители трансляции: 1' })).toBeVisible({ timeout: 15000 })
    await expect(ownerParticipants.getByRole('img', { name: 'Смотрит вашу трансляцию' })).toHaveCount(1)
    await receiver.locator('summary[aria-label="Статистика"]').click()
    const stats = receiver.getByRole('dialog', { name: 'Статистика трансляции' })
    await expect(stats.getByText('Выбрано отправителем', { exact: true })).toBeVisible()
    const confirmation = await stats.locator('dl > div').filter({ has: receiver.locator('dt', { hasText: /^Подтверждение конфигурации$/ }) }).locator('dd').innerText()
    assert.ok(['Конфигурация передана отправителем', 'Обновление конфигурации ожидается', 'Нет подтверждения от отправителя'].includes(confirmation))
    console.log('stage=screen-configuration-status:' + confirmation)
    await expect(stats.getByText('Сейчас у зрителя', { exact: true })).toBeVisible()
    await expect(stats.getByText('Декодирование', { exact: true })).not.toBeVisible()
    await receiver.screenshot({ path: input.directory + '/screen-share-compact-statistics.png' })
    await stats.getByText('Технические данные', { exact: true }).click()
    await expect(stats.getByText('Декодирование', { exact: true })).toBeVisible()
    await receiver.keyboard.press('Escape')
    await expect(stats).toHaveCount(0)
    await miniPlayerInterface(sender, receiver, input, report, subscriptions)
    await sender.getByRole('button', { name: 'Остановить свою трансляцию', exact: true }).click()
    await expect(dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true })).toBeEnabled()
    await expect(receiver.getByTestId('stream-select')).toHaveCount(0, { timeout: 15000 })
    await expect.poll(() => sender.evaluate(() => window.__qaShareUI.track.readyState)).toBe('ended')
    const observation = await sender.evaluate(() => ({ captures: window.__qaShareUI.captures, activated: window.__qaShareUI.activated }))
    assert.equal(observation.captures, 3); assert.deepEqual(observation.activated, [true, true, true])
    for (const page of [sender, receiver]) await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
    report.screen_share_interface = { boundary: 'synthetic canvas and quiet oscillator; OS picker NOT_RUN', actual_api_sfu: true, cancel_without_publication: true, permission_denied_visible: true, owner_preview_decoded: true, owner_stopped_from_viewer: true, receiver_view_decoded: true, owner_and_viewer_audience_visible: true, ended_source_track: true, voice_retained: true, selected_configuration_measured_separate: true, configuration_observed: confirmation, diagnostics_optional: true, ...observation, media_quality: 'NOT_RUN' }
  } finally {
    await sender.evaluate(() => {
      const state = window.__qaShareUI
      navigator.mediaDevices.getDisplayMedia = state.original
      clearInterval(state.timer); state.stream?.getTracks().forEach(track => track.stop()); state.oscillator?.stop(); void state.sound?.close()
      delete window.__qaShareUI
    })
  }
}
