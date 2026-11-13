import { describe, expect, it } from 'vitest'
import { MicrophoneDsp } from './dsp'

function block(dsp: MicrophoneDsp, level: number, frames = 480) {
  const output = new Float32Array(frames)
  dsp.process(new Float32Array(frames).fill(level), output)
  return output
}
describe('prepublication microphone DSP', () => {
  it('bypasses VAD in PTT and keeps unity amplitude', () => {
    const dsp = new MicrophoneDsp(48000)
    dsp.configure({ vadThresholdDb: -20, microphoneGainPercent: 100 }, false, false)
    expect(block(dsp, .001)[479]).toBeCloseTo(.001)
  })
  it('rejects background, retains onset and speech tail, then closes', () => {
    const dsp = new MicrophoneDsp(48000)
    dsp.configure({ vadThresholdDb: -50, microphoneGainPercent: 100 }, true, false)
    expect(block(dsp, .0001).every(value => value === 0)).toBe(true)
    block(dsp, .1); block(dsp, .1)
    expect(block(dsp, .1)[0]).toBeCloseTo(.1)
    expect(block(dsp, .001)[479]).toBeGreaterThan(0)
    for (let i = 0; i < 25; i++) block(dsp, .0001)
    expect(block(dsp, .0001).every(value => value === 0)).toBe(true)
  })
  it('ramps the VAD gate instead of cutting abruptly at opening and closing', () => {
    const dsp = new MicrophoneDsp(48000)
    dsp.configure({ vadThresholdDb: -50, microphoneGainPercent: 100 }, true, false)
    block(dsp, .001); block(dsp, .001)
    const attack = block(dsp, .1)
    expect(attack[0]).toBeGreaterThan(0); expect(attack[0]).toBeLessThan(.00002)
    expect(attack[479]).toBeCloseTo(.001, 5)
    for (let i = 0; i < 19; i++) block(dsp, .001)
    const release = block(dsp, .001)
    expect(release[0]).toBeGreaterThan(0)
    expect(release[479]).toBeLessThan(release[0])
    for (let i = 0; i < 5; i++) block(dsp, .001)
    expect(block(dsp, .001).every(value => value === 0)).toBe(true)
  })
  it('preserves a quiet onset in the 20 ms pre-roll before louder speech', () => {
    const dsp = new MicrophoneDsp(48000)
    dsp.configure({ vadThresholdDb: -50, microphoneGainPercent: 100 }, true, false)
    block(dsp, 0); block(dsp, .001); block(dsp, .1)
    const onset = block(dsp, .1)
    expect(onset.every(value => Math.abs(value - .001) < .00001)).toBe(true)
  })
  it('supports silence, double gain/clipping and AGC restores manual gain', () => {
    const dsp = new MicrophoneDsp(48000)
    const settings = { vadThresholdDb: -50, microphoneGainPercent: 200 }
    dsp.configure(settings, false, false)
    block(dsp, .25); expect(block(dsp, .25)[479]).toBeCloseTo(.5)
    expect(block(dsp, .8)[479]).toBe(1); expect(dsp.clipping).toBe(true)
    dsp.configure(settings, false, true)
    block(dsp, .25); expect(block(dsp, .25)[479]).toBeCloseTo(.25)
    dsp.configure(settings, false, false)
    block(dsp, .25); expect(block(dsp, .25)[479]).toBeCloseTo(.5)
    dsp.configure({ ...settings, microphoneGainPercent: 0 }, false, false)
    expect(block(dsp, .8).every(value => value === 0)).toBe(true)
    dsp.reset(); expect(dsp.gateOpen).toBe(false)
  })
})
