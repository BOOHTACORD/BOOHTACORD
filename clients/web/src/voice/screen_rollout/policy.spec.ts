import { afterEach, describe, expect, it, vi } from 'vitest'
import { screenMediaRollout } from './policy'
import { screenPublishPlan } from '../screen_publisher/plan'
import { LatestScreenPreviewUploader } from '../screen_preview/uploader'
import { LatestScreenPreviewReader } from '../screen_preview/reader'

afterEach(() => vi.unstubAllEnvs())
describe('independent immutable screen feature switches', () => {
  it('preserves compatible metadata/JPEG defaults with single-layer publication', () => {
    expect(screenMediaRollout({})).toEqual({ descriptor: true, jpegPreview: true, codecPolicy: true, boundedSimulcast: false })
  })
  it('strictly parses declared booleans, never treating malformed opt-in as enabled', () => {
    for (const value of ['TRUE', '1', 'yes', 'true ', {}]) {
      expect(screenMediaRollout({ VITE_SCREEN_SHARE_BOUNDED_SIMULCAST: value }).boundedSimulcast).toBe(false)
    }
    expect(screenMediaRollout({ VITE_SCREEN_PREVIEWS_V1: 'false' })).toMatchObject({ jpegPreview: false, descriptor: true })
  })
  it('freezes a client snapshot so active publication cannot observe later config changes', () => {
    const source = { VITE_SCREEN_SHARE_BOUNDED_SIMULCAST: 'true' }
    const snapshot = screenMediaRollout(source)
    source.VITE_SCREEN_SHARE_BOUNDED_SIMULCAST = 'false'
    expect(Object.isFrozen(snapshot)).toBe(true)
    expect(snapshot.boundedSimulcast).toBe(true)
    expect(screenMediaRollout(source).boundedSimulcast).toBe(false)
  })
  it('disables new codec fallback conservatively without changing capture/audio or simulcast', () => {
    const rollout = screenMediaRollout({ VITE_SCREEN_SHARE_CODEC_POLICY: 'false' })
    expect(screenPublishPlan('P1080_30', undefined, false, rollout.codecPolicy)).toMatchObject({ videoCodec: 'vp8', simulcast: false })
    expect(() => screenPublishPlan('P1080_30', [{ mimeType: 'video/H264' }], false, rollout.codecPolicy)).toThrow('No supported')
  })
  it('disabled JPEG sender makes no HTTP generation or upload request', async () => {
    const request = vi.fn()
    const sender = new LatestScreenPreviewUploader(request, false)
    await sender.start('11111111-1111-4111-8111-111111111111')
    await sender.stop()
    expect(request).not.toHaveBeenCalled()
  })
  it('disabled JPEG reader retains ordinary cards without requesting or subscribing media', async () => {
    const sink = { apply: vi.fn(), clear: vi.fn() }, request = vi.fn(), read = vi.fn()
    const reader = new LatestScreenPreviewReader(sink, request, read, { enabled: false })
    reader.accept({ leaseId: '11111111-1111-4111-8111-111111111111', generationId: '22222222-2222-4222-8222-222222222222', revision: 1 })
    await Promise.resolve(); reader.clear()
    expect(request).not.toHaveBeenCalled(); expect(read).not.toHaveBeenCalled(); expect(sink.apply).not.toHaveBeenCalled()
  })
})
