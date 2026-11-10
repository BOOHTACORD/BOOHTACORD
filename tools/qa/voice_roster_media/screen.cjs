function publishedInBoth(prejoin, sidebar, published) {
  const expected = published ? 1 : 0
  return prejoin === expected && sidebar === expected
}

function decoded(value) { return value?.width > 0 && value?.frames > 0 }

async function exercise(sender, observer, receiver, until, capture, captureReceiver) {
  await sender.evaluate(() => {
    navigator.mediaDevices.getDisplayMedia = async () => {
      const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 360
      const context = canvas.getContext('2d'); let frame = 0
      const draw = () => { context.fillStyle = ++frame % 2 ? '#163d62' : '#1d6144'; context.fillRect(0, 0, 640, 360) }
      draw(); const timer = setInterval(draw, 100)
      const stream = canvas.captureStream(10)
      window.__qaScreenTrack = stream.getVideoTracks()[0]
      window.__qaScreenTrack.addEventListener('ended', () => clearInterval(timer))
      return stream
    }
  })
  const dock = sender.getByTestId('voice-dock')
  const member = scope => observer.locator(`${scope} .voice-roster-member`)
    .filter({ has: observer.getByText('qa_admin', { exact: true }) }).getByRole('img', { name: 'Показывает экран' })
  const visible = async published => publishedInBoth(await member('.voice-prejoin').count(), await member('.sidebar').count(), published)
  await dock.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true }).click()
  const dialog = sender.getByRole('dialog', { name: 'Демонстрация экрана', exact: true })
  await dialog.getByRole('radio', { name: '720p' }).check()
  await dialog.getByRole('button', { name: 'Начать трансляцию', exact: true }).click()
  await until(() => sender.evaluate(() => window.__qaPeers.some(peer => peer.getSenders().some(sender =>
    sender.track?.kind === 'video' && sender.track.readyState === 'live'))), 'screen sender missing')
  await until(() => visible(true), 'screen publication missing from roster')
  await capture('screen-sharing')
  await receiver.bringToFront()
  const preview = receiver.getByTestId('participant-screen-preview')
  const streamButton = receiver.getByRole('button', { name: /^Трансляции · \d+$/ })
  await until(async () => await preview.isVisible() || await streamButton.isVisible(), 'receiver screen selector missing')
  if (await preview.isVisible()) await preview.click()
  else { await streamButton.click(); await receiver.getByTestId('stream-select').first().click() }
  const video = receiver.locator('video.screen-player')
  await until(async () => {
    if (!await video.isVisible()) return false
    return decoded(await video.evaluate(element => ({ width: element.videoWidth, frames: element.getVideoPlaybackQuality().totalVideoFrames })))
  }, 'receiver did not decode screen frames')
  await captureReceiver('screen-received')
  await dock.getByRole('button', { name: 'Остановить демонстрацию экрана', exact: true }).click()
  await until(() => visible(false), 'screen publication remained in roster')
  await until(() => sender.evaluate(() => window.__qaScreenTrack?.readyState === 'ended'), 'screen track did not stop')
  await capture('screen-stopped')
}

module.exports = { publishedInBoth, decoded, exercise }
