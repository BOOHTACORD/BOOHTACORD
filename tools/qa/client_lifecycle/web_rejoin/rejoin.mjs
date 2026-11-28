import { channel, expect, security } from '../request.mjs'
import { selectVisibleStream } from '../../critical_client_acceptance/select_stream.mjs'
import { rejoinThroughDiscoveryGap } from './connect.mjs'

export async function logoutAndRejoin(receiver, input, report) {
  const mini = receiver.locator('.voice-room--mini')
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
  await receiver.getByLabel('Логин', { exact: true }).fill('qa_member')
  await receiver.getByLabel('Пароль', { exact: true }).fill(input.password)
  await receiver.getByRole('button', { name: 'Войти', exact: true }).click()
  await expect(receiver.getByTestId('app-shell')).toBeVisible()
  await channel(receiver, 'VoiceLab')
  await rejoinThroughDiscoveryGap(receiver, report)
  await selectVisibleStream(receiver)
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => v.videoWidth > 0)).toBe(true)
  const frames = await receiver.locator('video.screen-player').evaluate(v => v.getVideoPlaybackQuality().totalVideoFrames)
  await expect.poll(() => receiver.locator('video.screen-player').evaluate(v => v.getVideoPlaybackQuality().totalVideoFrames), { timeout: 10000 }).toBeGreaterThan(frames)
  report.web_rejoin_discovery.decoded_video_frames_advanced = true
  console.log('stage=mini-player-controls-and-cleanup-accepted')
  await receiver.screenshot({ path: input.directory+'/web-rejoin-recovered.png' })
}
