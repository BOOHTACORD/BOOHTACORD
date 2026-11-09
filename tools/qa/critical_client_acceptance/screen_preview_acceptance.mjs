import assert from 'node:assert/strict'
import { expect } from '../client_lifecycle/request.mjs'

export async function verifyScreenPreview(sender, receiver, input) {
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
  console.log('stage=screen-short-geometry-ok')
  await expect.poll(() => sender.locator('video.screen-player').evaluate(video => video.getVideoPlaybackQuality().totalVideoFrames), { timeout: 5000 }).toBeGreaterThan(framesBeforeShortViewport)
  console.log('stage=screen-short-frames-ok')
  await sender.screenshot({ path: input.directory + '/screen-share-owner-preview-short-height.png' })
  await sender.setViewportSize(ownerViewport)
  await receiver.bringToFront()
  const participantPreview = receiver.getByTestId('participant-screen-preview')
  await expect(participantPreview).toBeVisible({ timeout: 30000 })
  console.log('stage=screen-preview-card-ok')
  await participantPreview.scrollIntoViewIfNeeded()
  await expect(participantPreview.locator('img')).toBeVisible({ timeout: 30000 })
  await expect.poll(() => participantPreview.locator('img').evaluate(image => image.naturalWidth > 0), { timeout: 30000 }).toBe(true)
  console.log('stage=screen-preview-decoded-ok')
  const firstServerPreview = await participantPreview.locator('img').getAttribute('src')
  assert.ok(firstServerPreview, 'the server must deliver an initial thumbnail')
  const refreshStartedAt = Date.now()
  await expect.poll(() => participantPreview.locator('img').getAttribute('src'), { timeout: 45000, intervals: [1000] }).not.toBe(firstServerPreview)
  const refreshElapsedMs = Date.now() - refreshStartedAt
  assert.ok(refreshElapsedMs >= 25000, `server preview refreshed too early: ${refreshElapsedMs}ms`)
  console.log('stage=screen-preview-refresh-ok')
  console.log('stage=server-screen-preview-refreshed:' + refreshElapsedMs)
  await receiver.screenshot({ path: input.directory + '/screen-share-listener-participant-cards.png' })
  console.log('stage=screen-share-inline-participant-preview:decoded-thumbnail')
}
