import { afterEach, expect, it, vi } from 'vitest'
import * as capabilities from '../capabilities'
import { fixture } from './auto_fixture'
afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })
const options = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'auto' as const }
function enabled() {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.spyOn(capabilities, 'supportsRnnoise').mockReturnValue(true)
  return fixture()
}
it('keeps browser suppression when the measured candidate is rejected', async () => {
  const f = enabled()
  f.dependencies.preflightAuto.mockResolvedValue(false)
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.preflightAuto).toHaveBeenCalledExactlyOnceWith('rnnoise')
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser' })
  await f.adapter.dispose()
})
it('never applies late preflight to a disposed capture', async () => {
  const f = enabled()
  let complete!: (value: boolean) => void, entered!: () => void
  const started = new Promise<void>(resolve => { entered = resolve })
  f.dependencies.preflightAuto.mockImplementation(() => { entered(); return new Promise(resolve => { complete = resolve }) })
  const pending = f.adapter.setEnabled(true, options)
  const rejected = expect(pending).rejects.toThrow('закрыто')
  await started
  const disposal = f.adapter.dispose()
  complete(true)
  await rejected; await disposal
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.dependencies.publishTrack).not.toHaveBeenCalled()
  expect(f.track.applyConstraints).not.toHaveBeenCalled()
  expect(f.source.enabled).toBe(false)
})
it('does not re-probe on ordinary mute/unmute with unchanged options', async () => {
  const f = enabled()
  await f.adapter.setEnabled(true, options)
  await f.adapter.setEnabled(false, options)
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.preflightAuto).toHaveBeenCalledOnce()
  await f.adapter.dispose()
})
it('retries measured RNNoise when selected DeepFilter fails to initialize', async () => {
  vi.stubEnv('VITE_AUTO_DEEPFILTER_RESEARCH', 'true')
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = enabled()
  f.track.setProcessor.mockRejectedValueOnce(Error('model init'))
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.preflightAuto.mock.calls).toEqual([['deepfilter'], ['rnnoise']])
  expect(f.dependencies.createProcessor.mock.calls.map(call => call[1]?.noiseSuppressionMode)).toEqual(['deepfilter', 'rnnoise'])
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'rnnoise', status: 'active' })
  await f.adapter.dispose()
})

for (const muted of [false, true]) it(`runtime DeepFilter failure tries measured RNNoise, muted=${muted}`, async () => {
  vi.stubEnv('VITE_AUTO_DEEPFILTER_RESEARCH', 'true')
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = enabled()
  await f.adapter.setEnabled(true, options)
  const callbacks = f.dependencies.createProcessor.mock.calls[0][0] as { onFailure(reason: string): void }
  callbacks.onFailure('overload')
  expect(f.output.enabled).toBe(false)
  await f.adapter.setEnabled(!muted, options)
  expect(f.dependencies.preflightAuto.mock.calls).toEqual([['deepfilter'], ['rnnoise']])
  const resumed = f.dependencies.createProcessor.mock.calls[1][0] as { onState(state: unknown): void }
  resumed.onState({ requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active' })
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'rnnoise', status: 'active', fallbackReason: 'overload' })
  expect(f.output.enabled).toBe(!muted)
  await f.adapter.dispose()
})

it('uses confirmed browser NS after runtime failure when RNNoise is rejected', async () => {
  vi.stubEnv('VITE_AUTO_DEEPFILTER_RESEARCH', 'true')
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = enabled()
  f.dependencies.preflightAuto.mockImplementation(async engine => engine === 'deepfilter')
  await f.adapter.setEnabled(true, options)
  const callbacks = f.dependencies.createProcessor.mock.calls[0][0] as { onFailure(reason: string): void }
  callbacks.onFailure('overload')
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.preflightAuto.mock.calls).toEqual([['deepfilter'], ['rnnoise']])
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'overload' })
  expect(f.track.applyConstraints).toHaveBeenLastCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  await f.adapter.dispose()
})
