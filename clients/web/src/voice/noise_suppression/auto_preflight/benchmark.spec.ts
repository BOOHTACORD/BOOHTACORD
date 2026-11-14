import { expect, it } from 'vitest'
import { benchmark, eligible } from './benchmark'

function run(duration: (step: number) => number, output = (frame: Float32Array) => frame) {
  let clock = 0, calls = 0
  return benchmark(frame => { clock += duration(calls++); return output(frame) }, () => clock)
}
it('measures 32 frames after eight warmups without accepting a fake ready bit', () => {
  expect(run(() => 1)).toEqual({ ready: true, p95Ms: 1, maxMs: 1, elapsedMs: 40, frames: 32 })
  expect(eligible({ ready: true })).toBe(false)
})
it('rejects sustained load, individual spikes and exhausted deadlines', () => {
  expect(run(() => 3.1).ready).toBe(false)
  expect(run(i => i === 10 ? 8.1 : 1).ready).toBe(false)
  expect(run(() => 26).ready).toBe(false)
})
it('rejects invalid output, exceptions and non-monotonic clocks', () => {
  for (const sample of [NaN, Infinity, 1.01, -1.01]) {
    expect(run(() => 1, f => { f[0] = sample; return f }).ready).toBe(false)
  }
  expect(run(() => 1, () => new Float32Array(479)).ready).toBe(false)
  expect(run(() => 1, () => { throw Error('trapped') }).ready).toBe(false)
  let clock = 100
  expect(benchmark(f => f, () => clock--).ready).toBe(false)
})
it('validates the worker metrics independently before granting eligibility', () => {
  const valid = { ready: true, p95Ms: 1, maxMs: 2, elapsedMs: 40, frames: 32 }
  expect(eligible(valid)).toBe(true)
  for (const bad of [{frames:31}, {p95Ms:-1}, {p95Ms:NaN}, {maxMs:Infinity}, {maxMs:.5}, {elapsedMs:1}, {elapsedMs:1001}]) {
    expect(eligible({ ...valid, ...bad })).toBe(false)
  }
})
