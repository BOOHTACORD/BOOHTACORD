import { afterEach, expect, it, vi } from 'vitest'
import { browser, fixture, off, rnnoise } from '../../../../tests/audio/recapture_fixture'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })

it('reacquires and publishes only a muted processed track when live constraints are ignored', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture()
  await f.adapter.setEnabled(true, browser)
  await f.adapter.setProcessing(rnnoise)
  expect(f.events).toEqual(['capture:true', 'publish:false', 'unpublish', 'capture:false', 'publish:false'])
  expect(f.dependencies.createProcessor).toHaveBeenCalledOnce()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active' })
  expect(f.captures[0].source.enabled).toBe(false)
  await f.adapter.dispose()
})

it('preserves an explicitly selected microphone during reacquisition', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.switchDevice('synthetic-device', 'prejoin')
  await f.adapter.setEnabled(true, browser)
  await f.adapter.setProcessing(rnnoise)
  expect(f.dependencies.createTrack).toHaveBeenLastCalledWith(expect.objectContaining({ deviceId: { exact: 'synthetic-device' }, noiseSuppression: false }))
  await f.adapter.dispose()
})

it('reacquires before publishing when disabling all suppression is ignored', async () => {
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  await f.adapter.setProcessing(off)
  expect(f.events).toEqual(['capture:true', 'publish:false', 'unpublish', 'capture:false', 'publish:false'])
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'off', effectiveMode: 'off', status: 'active' })
  expect(f.captures[0].source.enabled).toBe(false)
  await f.adapter.dispose()
})

it('reacquires browser suppression when enabling it dynamically is ignored', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, rnnoise)
  await f.adapter.setProcessing(browser)
  expect(f.events).toEqual(['capture:false', 'publish:false', 'unpublish', 'capture:true', 'publish:false'])
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'browser', effectiveMode: 'browser', status: 'active' })
  expect(f.captures[0].source.enabled).toBe(false)
  await f.adapter.dispose()
})

it('stops each replaced source across repeated mode changes', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, browser)
  for (let i = 0; i < 30; i++) {
    await f.adapter.setProcessing(rnnoise)
    await f.adapter.setProcessing(browser)
  }
  expect(f.dependencies.publishTrack).toHaveBeenCalledTimes(61)
  expect(f.dependencies.unpublishTrack).toHaveBeenCalledTimes(60)
  expect(f.captures.slice(0, -1).every(c => !c.source.enabled && !c.output.enabled)).toBe(true)
  await f.adapter.dispose()
  expect(f.captures.every(c => !c.source.enabled && !c.output.enabled)).toBe(true)
})
