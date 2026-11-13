import { afterEach, expect, it, vi } from 'vitest'
import { fixture, rnnoise } from './recapture_fixture'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })

it('republishes the selected device when restarting it ignores suppression constraints', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture()
  await f.adapter.switchDevice('previous', 'prejoin')
  await f.adapter.setEnabled(true, rnnoise)
  const track = await f.dependencies.createTrack.mock.results[0].value
  vi.mocked(track.restartTrack).mockImplementationOnce(async () => {
    track.mediaStreamTrack = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: true }) } as unknown as MediaStreamTrack
  })
  expect(await f.adapter.switchDevice('next')).toBe(true)
  expect(f.dependencies.createTrack).toHaveBeenLastCalledWith(expect.objectContaining({
    deviceId: { exact: 'next' }, noiseSuppression: false,
  }))
  expect(f.events).toEqual(['capture:false', 'publish:false', 'unpublish', 'capture:false', 'publish:false'])
  expect(f.adapter.inputSelection).toMatchObject({ deviceId: 'next', outcome: 'success' })
  await f.adapter.dispose()
})

it('stays muted without retrying when device replacement cannot unpublish the old track', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, rnnoise)
  const track = await f.dependencies.createTrack.mock.results[0].value
  vi.mocked(track.restartTrack).mockImplementationOnce(async () => {
    track.mediaStreamTrack = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: true }) } as unknown as MediaStreamTrack
  })
  f.dependencies.unpublishTrack.mockRejectedValueOnce(new Error('uncertain removal'))
  await expect(f.adapter.switchDevice('next')).rejects.toThrow('uncertain removal')
  expect(f.dependencies.createTrack).toHaveBeenCalledTimes(1)
  expect(f.dependencies.publishTrack).toHaveBeenCalledTimes(1)
  expect(f.adapter.runtimeState.status).toBe('error')
  expect(f.adapter.inputSelection.outcome).toBe('error')
  expect(f.adapter.readOutputTrack()?.enabled).toBe(false)
  await f.adapter.dispose()
})
