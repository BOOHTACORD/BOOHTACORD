import { expect, it, vi } from 'vitest'
import { selectAutoEngine } from './capabilities'

it('selects v0.2 only after a measured preflight', async () => {
  const probe = vi.fn(async () => true)
  expect(await selectAutoEngine({ v02: false, supported: true, probe })).toBe('browser')
  expect(await selectAutoEngine({ v02: true, supported: false, probe })).toBe('browser')
  expect(probe).not.toHaveBeenCalled()
  expect(await selectAutoEngine({ v02: true, supported: true, probe })).toBe('rnnoise')
  expect(probe).toHaveBeenCalledExactlyOnceWith('rnnoise')
})

it('rejects missing, failing and throwing performance probes', async () => {
  expect(await selectAutoEngine({ v02: true, supported: true })).toBe('browser')
  expect(await selectAutoEngine({ v02: true, supported: true, probe: async () => false })).toBe('browser')
  expect(await selectAutoEngine({ v02: true, supported: true, probe: async () => 'ready' as unknown as boolean })).toBe('browser')
  expect(await selectAutoEngine({ v02: true, supported: true, probe: async () => { throw Error('failed') } })).toBe('browser')
})

it('tries opted-in DeepFilter then measured RNNoise on rejection', async () => {
  const probe = vi.fn(async (engine: string) => engine === 'rnnoise')
  expect(await selectAutoEngine({ v02: true, supported: true, deepfilterResearch: true, probe })).toBe('rnnoise')
  expect(probe.mock.calls).toEqual([['deepfilter'], ['rnnoise']])
  probe.mockResolvedValue(true)
  expect(await selectAutoEngine({ v02: true, supported: true, deepfilterResearch: true, probe })).toBe('deepfilter')
})

it('never probes an opted-out DeepFilter candidate', async () => {
  const probe = vi.fn(async () => true)
  expect(await selectAutoEngine({ v02: false, supported: true, deepfilterResearch: false, probe })).toBe('browser')
  expect(probe).not.toHaveBeenCalled()
})
