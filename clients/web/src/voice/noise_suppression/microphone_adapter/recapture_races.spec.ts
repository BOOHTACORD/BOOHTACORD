import { afterEach, expect, it, vi } from 'vitest'
import { browser, fixture, rnnoise } from '../../../../tests/audio/recapture_fixture'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })

it('keeps the replacement muted when mute arrives during capture', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  const create = f.dependencies.createTrack.getMockImplementation()!
  let release!: () => void
  f.dependencies.createTrack.mockImplementationOnce(async options => {
    await new Promise<void>(resolve => { release = resolve })
    return create(options)
  })
  const switching = f.adapter.setProcessing(rnnoise)
  await vi.waitFor(() => expect(release).toBeTypeOf('function'))
  const muting = f.adapter.setEnabled(false, rnnoise)
  release(); await Promise.all([switching, muting])
  expect(f.events.at(-1)).toBe('publish:false')
  expect(f.captures.at(-1)!.source.enabled).toBe(false)
  expect(f.captures.at(-1)!.output.enabled).toBe(false)
  await f.adapter.dispose()
})

it('stops a capture that returns after disposal without publishing it', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  const create = f.dependencies.createTrack.getMockImplementation()!
  let release!: () => void
  f.dependencies.createTrack.mockImplementationOnce(async options => {
    await new Promise<void>(resolve => { release = resolve })
    return create(options)
  })
  const switching = f.adapter.setProcessing(rnnoise)
  await vi.waitFor(() => expect(release).toBeTypeOf('function'))
  const disposing = f.adapter.dispose(); release()
  await expect(switching).rejects.toThrow()
  await disposing
  expect(f.dependencies.publishTrack).toHaveBeenCalledTimes(1)
  expect(f.captures.at(-1)!.source.enabled).toBe(false)
})

it('fails muted when unpublication has an uncertain outcome', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  f.dependencies.unpublishTrack.mockRejectedValueOnce(new Error('unpublish failed'))
  await expect(f.adapter.setProcessing(rnnoise)).rejects.toThrow('unpublish failed')
  expect(f.dependencies.createTrack).toHaveBeenCalledTimes(1)
  expect(f.dependencies.publishTrack).toHaveBeenCalledTimes(1)
  expect(f.adapter.runtimeState).toMatchObject({ effectiveMode: 'unknown', status: 'error' })
  expect(f.captures[0].source.enabled).toBe(false)
  await f.adapter.dispose()
})

it('restores the previous browser mode when publishing a replacement fails', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  f.dependencies.publishTrack.mockRejectedValueOnce(new Error('publish failed'))
  await expect(f.adapter.setProcessing(rnnoise)).rejects.toThrow('publish failed')
  expect(f.dependencies.publishTrack).toHaveBeenCalledTimes(3)
  expect(f.events.at(-1)).toBe('publish:false')
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'browser', effectiveMode: 'browser' })
  expect(f.captures[1].source.enabled).toBe(false)
  const restored = await f.dependencies.createTrack.mock.results.at(-1)!.value
  await f.adapter.switchDevice('synthetic-device')
  expect(restored.restartTrack).toHaveBeenCalledWith(expect.objectContaining({ noiseSuppression: true }))
  await f.adapter.dispose()
})

it('fails muted when a failed replacement publication cannot be confirmed removed', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  f.dependencies.publishTrack.mockRejectedValueOnce(new Error('publish failed'))
  f.dependencies.unpublishTrack.mockResolvedValueOnce(undefined).mockRejectedValueOnce(new Error('removal unknown'))
  await expect(f.adapter.setProcessing(rnnoise)).rejects.toThrow('publish failed')
  expect(f.dependencies.publishTrack).toHaveBeenCalledTimes(2)
  expect(f.adapter.runtimeState).toMatchObject({ status: 'error', effectiveMode: 'unknown' })
  expect(f.captures.every(c => !c.source.enabled && !c.output.enabled)).toBe(true)
  await f.adapter.dispose()
})

it('does not claim browser suppression is active when reacquisition cannot enable it', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, rnnoise)
  const create = f.dependencies.createTrack.getMockImplementation()!
  f.dependencies.createTrack.mockImplementationOnce(async options => {
    const track = await create(options)
    track.mediaStreamTrack.getSettings = () => ({ noiseSuppression: false })
    return track
  })
  await f.adapter.setProcessing(browser)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'browser', effectiveMode: 'off', status: 'unsupported' })
  await f.adapter.dispose()
})

it('reacquires browser suppression after a running model fails', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, rnnoise)
  f.dependencies.createProcessor.mock.calls[0][0].onFailure('overload')
  await vi.waitFor(() => expect(f.adapter.runtimeState.status).toBe('fallback'))
  await vi.waitFor(() => expect(f.events).toEqual(['capture:false', 'publish:false', 'unpublish', 'capture:true', 'publish:false']))
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'browser', fallbackReason: 'overload' })
  expect(f.captures[0].source.enabled).toBe(false)
  await f.adapter.dispose()
})
