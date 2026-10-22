import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { api, channel, expect, openNavigation, security, login } from '../client_lifecycle/request.mjs'
const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
const { SignalRequest } = require('@livekit/protocol')

export async function observeMiniSubscriptions(page) {
  const counts = { subscribe: 0, unsubscribe: 0 }
  await page.routeWebSocket(url => new URL(url).pathname.startsWith('/qa-sfu'), socket => {
    const server = socket.connectToServer()
    socket.onMessage(data => {
      try {
        const request = typeof data === 'string' ? SignalRequest.fromJsonString(data) : SignalRequest.fromBinary(data)
        const subscription = request.message?.case === 'subscription' ? request.message.value : request.subscription
        if (subscription) counts[subscription.subscribe ? 'subscribe' : 'unsubscribe'] += subscription.trackSids?.length || subscription.participantTracks?.reduce((n, p) => n + (p.trackSids?.length || 0), 0) || 0
      } catch { /* Forward every frame unchanged; retain counts only. */ }
      server.send(data)
    })
    server.onMessage(data => socket.send(data))
  })
  return () => ({ ...counts })
}

export async function miniPlayerInterface(sender, receiver, input, report, subscriptions) {
  const mini = receiver.locator('.voice-room--mini')
  console.log('stage=mini-player-actual-start')
  const initial = subscriptions()
  assert.equal(initial.subscribe, 2)
  await receiver.evaluate(() => {
    const video = document.querySelector('video.screen-player'), audio = document.querySelector('.screen-viewer audio')
    window.__qaMiniIdentity = { video, audio, videoStream: video.srcObject, audioStream: audio.srcObject,
      tracks: [...video.srcObject.getTracks(), ...audio.srcObject.getTracks()], peers: window.__qaPeers.filter(p => p.connectionState === 'connected') }
  })
  const retained = async () => {
    assert.equal(await receiver.evaluate(() => {
      const state = window.__qaMiniIdentity, video = document.querySelector('video.screen-player'), audio = document.querySelector('.screen-viewer audio')
      return video === state.video && audio === state.audio && video.srcObject === state.videoStream && audio.srcObject === state.audioStream &&
        state.tracks.every(t => t.readyState === 'live') && state.peers.every(p => p.connectionState === 'connected') &&
        window.__qaPeers.filter(p => p.connectionState === 'connected').length === state.peers.length
    }), true)
    assert.deepEqual(subscriptions(), initial)
  }
  const safeChat = async () => {
    assert.equal(await receiver.evaluate(() => {
      const player = document.querySelector('.voice-room--mini').getBoundingClientRect(), composer = document.querySelector('.composer').getBoundingClientRect(), dock = document.querySelector('[data-testid=voice-dock]').getBoundingClientRect()
      const apart = (a, r) => a.right <= r.left || a.left >= r.right || a.bottom <= r.top || a.top >= r.bottom
      const header = document.querySelector('.text-conversation > .conversation-header, .direct-message-conversation > .conversation-header').getBoundingClientRect(), members = document.querySelector('.members-panel')?.getBoundingClientRect()
      return player.left >= 0 && player.right <= innerWidth && apart(player, composer) && apart(player, dock) && (!members || members.width === 0 || (apart(player, members) && apart(header, members))) && document.documentElement.scrollWidth <= innerWidth
    }), true)
    await retained()
  }
  // Set the existing per-stream mixer through its production volume control, including its CSS-hidden retained range at touch widths; this is a state-continuity check, not a claim that mobile exposes volume adjustment.
  const range = receiver.getByRole('slider', { name: 'Громкость звука выбранной демонстрации', exact: true, includeHidden: true })
  await range.evaluate(el => { el.value = '65'; el.dispatchEvent(new Event('input', { bubbles: true })) })
  await expect(receiver.getByRole('button', { name: /закрепить просмотр|открепить просмотр/i })).toHaveCount(0)
  await channel(receiver, 'Text')
  await expect(mini).toBeVisible(); await safeChat()
  await receiver.locator('.composer textarea').fill('Synthetic mini-player TEXT check')
  await receiver.locator('.composer textarea').press('Enter')
  await expect(receiver.locator('.composer textarea')).toHaveValue('')
  await receiver.screenshot({ path: input.directory + '/mini-player-text.png' })
  const senderProfile = await api(sender, '/me')
  const dm = await api(receiver, '/direct-messages', 'POST', { participant_id: senderProfile.body.account_id ?? senderProfile.body.id })
  assert.ok(dm.status === 200 || dm.status === 201)
  await openNavigation(receiver)
  await receiver.getByRole('button', { name: 'Личные', exact: true }).click()
  await receiver.getByRole('navigation', { name: 'Личные сообщения' }).locator('button.channel-button').filter({ hasText: senderProfile.body.display_name }).first().click()
  await expect(receiver.locator('.direct-message-conversation')).toBeVisible()
  await safeChat()
  await receiver.locator('.composer textarea').fill('Synthetic mini-player DM check')
  await receiver.locator('.composer textarea').press('Enter')
  await expect(receiver.locator('.composer textarea')).toHaveValue('')
  await receiver.screenshot({ path: input.directory + '/mini-player-dm.png' })
  console.log('stage=mini-player-text-dm-retained')
  await mini.getByRole('button', { name: 'Приостановить видео', exact: true }).click()
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => v.paused && !document.querySelector('.screen-viewer audio').paused)).toBe(true)
  await retained()
  await mini.getByRole('button', { name: 'Выключить звук трансляции', exact: true }).click()
  await expect.poll(() => receiver.locator('.screen-viewer audio').evaluate(audio => audio.muted)).toBe(true)
  await mini.getByRole('button', { name: 'Развернуть на всю область', exact: true }).click()
  await expect(receiver.locator('.voice-room--screen-expanded')).toBeVisible()
  await expect(receiver.locator('.voice-prejoin')).toHaveCount(0)
  // Compact clients intentionally use the persistent dock, just as the
  // voiceInterface acceptance above verifies; room controls stay hidden.
  if (input.viewport.width <= 600) {
    await expect(receiver.getByTestId('voice-dock').locator('.voice-actions')).toBeVisible()
    await expect(receiver.locator('.voice-room-controls')).toBeHidden()
  } else await expect(receiver.locator('.voice-room-controls')).toBeVisible()
  await expect(receiver.getByRole('button', { name: 'Продолжить видео', exact: true })).toBeVisible()
  await expect(receiver.getByRole('button', { name: 'Включить звук трансляции', exact: true })).toBeVisible()
  assert.equal(await range.inputValue(), '65')
  await retained()
  await receiver.keyboard.press('Escape')
  await expect(mini).toBeVisible(); await safeChat()
  await mini.getByRole('button', { name: 'Продолжить видео', exact: true }).click()
  await mini.getByRole('button', { name: 'Включить звук трансляции', exact: true }).click()
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => !v.paused && !document.querySelector('.screen-viewer audio').muted)).toBe(true)
  const frames = await receiver.locator('video.screen-player').evaluate(v => v.getVideoPlaybackQuality().totalVideoFrames)
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => v.getVideoPlaybackQuality().totalVideoFrames), { timeout: 10000 }).toBeGreaterThan(frames)
  await mini.getByRole('button', { name: 'Остановить просмотр', exact: true }).click()
  await expect(mini).toHaveCount(0)
  await expect.poll(() => subscriptions().unsubscribe - initial.unsubscribe).toBe(2)
  assert.equal(subscriptions().subscribe, initial.subscribe)
  assert.equal(await receiver.evaluate(() => {
    const state = window.__qaMiniIdentity
    return !state.video.srcObject && !state.audio.srcObject
  }), true)
  // Restore the original voice view so the following publisher-stop and transport-fault cases remain independent.
  await openNavigation(receiver)
  await receiver.getByRole('button', { name: 'Каналы', exact: true }).click()
  await channel(receiver, 'VoiceLab')
  await receiver.locator('[data-testid=stream-select]:visible').first().click()
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => v.videoWidth > 0)).toBe(true)
  await expect(receiver.getByRole('button', { name: /закрепить просмотр|открепить просмотр/i })).toHaveCount(0)
  await channel(receiver, 'Text')
  await receiver.evaluate(() => {
    const video = document.querySelector('video.screen-player'), audio = document.querySelector('.screen-viewer audio')
    window.__qaLogoutMedia = { video, audio, peers: window.__qaPeers.filter(p => p.connectionState === 'connected') }
  })
  await security(receiver)
  await expect(mini).toBeVisible()
  await receiver.getByRole('button', { name: 'Выйти из аккаунта', exact: true }).click()
  await receiver.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' }).getByRole('button', { name: 'Выйти', exact: true }).click()
  await expect(receiver.locator('.authentication-page')).toBeVisible()
  await expect(receiver.locator('.screen-viewer, .voice-room--mini')).toHaveCount(0)
  await expect.poll(() => receiver.evaluate(() => {
    const state = window.__qaLogoutMedia
    return !state.video.srcObject && !state.audio.srcObject && state.peers.every(p => p.connectionState === 'closed')
  })).toBe(true)
  console.log('stage=mini-player-auto-retained-logout-clean')
  await login(receiver, 'qa_member', input.password)
  await channel(receiver, 'VoiceLab')
  await receiver.getByRole('button', { name: 'Без микрофона', exact: true }).click()
  await expect(receiver.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 30000 })
  await receiver.locator('[data-testid=stream-select]:visible').first().click()
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => v.videoWidth > 0)).toBe(true)
  console.log('stage=mini-player-controls-and-cleanup-accepted')
  report.mini_player_interface = { actual_api_sfu: true, source: 'synthetic canvas and quiet oscillator', text_and_dm_send: true,
    same_video_audio_tracks_and_peer_connections: true, no_extra_subscription_during_navigation: true,
    pause_video_only: true, mute_and_volume_retained: true, expand_escape_returns_to_automatic_mini_player: true, explicit_stop_two_unsubscriptions: true,
    composer_and_dock_clear: true, settings_retains_viewer: true, automatic_mini_player_logout_detaches_outputs_and_closes_peers: true, hardware_capture_and_qoe: 'NOT_RUN' }
  await receiver.evaluate(() => { delete window.__qaMiniIdentity; delete window.__qaLogoutMedia })
}
