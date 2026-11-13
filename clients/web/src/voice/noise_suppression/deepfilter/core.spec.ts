import { describe, expect, it, vi } from 'vitest'
import { DeepFilterCore } from './core'

function fixture() {
  const engine = { process: vi.fn((frame: Float32Array) => frame.slice()), reset: vi.fn(), free: vi.fn() }
  const failed = vi.fn(), core = new DeepFilterCore(engine, failed)
  return { core, engine, failed }
}

describe('DeepFilter frame boundary', () => {
  it('handles variable quanta and clears delayed audio across mute', () => {
    const { core, engine } = fixture()
    expect(core.setMuted(false)).toBe(true)
    const received: number[] = []
    for (const size of [128, 256, 96, 480]) {
      const output = new Float32Array(size)
      expect(core.process(new Float32Array(size).fill(.25), output)).toBe(true)
      received.push(...output)
    }
    expect(received.slice(0, 480).every(value => value === 0)).toBe(true)
    expect(received.slice(480).every(value => value === .25)).toBe(true)
    core.setMuted(true); core.setMuted(false)
    const after = new Float32Array(960)
    core.process(new Float32Array(960), after)
    expect(after.every(value => value === 0)).toBe(true)
    expect(engine.reset).toHaveBeenCalledTimes(3)
  })

  it('fails closed once for nonfinite input or processor error', () => {
    for (const failure of ['input', 'engine'] as const) {
      const { core, engine, failed } = fixture(); core.setMuted(false)
      const input = new Float32Array(480), output = new Float32Array(480).fill(1)
      if (failure === 'input') input[2] = NaN
      else engine.process.mockImplementation(() => { throw new Error('private detail') })
      expect(core.process(input, output)).toBe(false)
      expect(output.every(value => value === 0)).toBe(true)
      expect(core.setMuted(false)).toBe(false)
      expect(failed).toHaveBeenCalledTimes(1)
    }
  })

  it('clears queued audio when capture disappears and frees once', () => {
    const { core, engine } = fixture(); core.setMuted(false)
    core.process(new Float32Array(480).fill(.5), new Float32Array(480))
    const absent = new Float32Array(128).fill(1)
    expect(core.process(undefined, absent)).toBe(true)
    expect(absent.every(value => value === 0)).toBe(true)
    const resumed = new Float32Array(960)
    core.process(new Float32Array(960), resumed)
    expect(resumed.every(value => value === 0)).toBe(true)
    core.dispose(); core.dispose(); expect(engine.free).toHaveBeenCalledTimes(1)
    expect(core.process(new Float32Array(128).fill(1), absent)).toBe(false)
    expect(absent.every(value => value === 0)).toBe(true)
  })

  it('silences an overfull queue and invalid model output', () => {
    const overflow = fixture(); overflow.core.setMuted(false)
    const out = new Float32Array(2048).fill(1)
    expect(overflow.core.process(new Float32Array(2048).fill(.1), out)).toBe(false)
    expect(out.every(value => value === 0)).toBe(true)
    expect(overflow.failed).toHaveBeenCalledWith('overload')
    const invalid = fixture(); invalid.core.setMuted(false)
    invalid.engine.process.mockReturnValue(new Float32Array(480).fill(NaN))
    expect(invalid.core.process(new Float32Array(480), new Float32Array(480))).toBe(false)
    expect(invalid.failed).toHaveBeenCalledWith('invalid-audio')
  })
})
