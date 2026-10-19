import assert from 'node:assert/strict'

// Run after the native reference-media capture. Transport is a fixture;
// these assertions exercise real Vue controls and their store action boundary.
export async function verifyViewerInteractions(page, width) {
  const results = []
  await page.evaluate(async () => {
    const { useVoiceConnectionStore } = await import('/src/voice/connection_store.ts')
    window.__viewerActionCalls = []
    window.__stopViewerActionCalls = useVoiceConnectionStore().$onAction(({ name, args }) => {
      if (['setScreenVolume', 'toggleScreenAudio'].includes(name)) window.__viewerActionCalls.push({ name, args })
    })
    window.__viewerInitialMedia = document.querySelector('.screen-player').srcObject
  })
  assert.equal(await page.getByRole('button', { name: /закрепить просмотр|открепить просмотр/i }).count(), 0)
  results.push('no-manual-pin-control')

  await page.locator('.stream-diagnostics > summary').click()
  const stats = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await stats.waitFor({ state: 'visible' })
  await page.keyboard.press('Escape')
  await stats.waitFor({ state: 'detached' })
  assert.equal(await page.locator('.stream-diagnostics > summary').evaluate(el => el === document.activeElement), true)
  results.push('statistics-escape-and-focus-return')

  await page.locator('.screen-fullscreen-button').click()
  await page.waitForFunction(() => document.fullscreenElement?.classList.contains('screen-stage'))
  await page.evaluate(() => document.exitFullscreen())
  await page.waitForFunction(() => !document.fullscreenElement)
  results.push('real-fullscreen-enter-and-exit')

  await page.locator('.screen-audio-toggle').click()
  assert.equal(await page.evaluate(() => window.__viewerActionCalls.some(call => call.name === 'toggleScreenAudio')), true)
  results.push('audio-toggle-reaches-existing-store-action')
  if (width > 720) {
    const volume = page.getByRole('slider', { name: 'Громкость звука выбранной демонстрации' })
    assert.equal(await volume.getAttribute('max'), '200')
    await volume.focus()
    await volume.press('ArrowRight')
    assert.equal(await page.evaluate(() => window.__viewerActionCalls.some(call => call.name === 'setScreenVolume' && call.args[0] === 66)), true)
    results.push('keyboard-volume-66-preserves-200-percent-range')
  }
  await page.locator('[data-testid="stream-select"]').nth(1).click()
  assert.match(await page.locator('.screen-stage-label').innerText(), /Экран Max/)
  assert.equal(await page.locator('[data-testid="stream-select"]').nth(1).getAttribute('aria-pressed'), 'true')
  assert.equal(await page.locator('.screen-audio-toggle').count(), 0)
  await page.locator('[data-testid="stream-select"]').first().click()
  await page.locator('.screen-audio-toggle').waitFor({ state: 'visible' })
  await page.waitForFunction(() => document.querySelector('.screen-player').videoWidth > 0)
  assert.equal(await page.locator('.screen-player').evaluate(video => video.srcObject === window.__viewerInitialMedia && video.videoWidth > 0), true)
  results.push('manual-stream-selection-and-media-element-preservation')
  await page.evaluate(() => window.__stopViewerActionCalls())
  return results
}
