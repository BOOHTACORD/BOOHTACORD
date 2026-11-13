import { test } from 'node:test'
import assert from 'node:assert/strict'
import { filterFrames } from './quality_core.mjs'

test('resets once and preserves ordered 480-sample frames', () => {
  let resets = 0, calls = 0
  const engine = { reset() { resets++ }, process(frame) { calls++; return Float32Array.from(frame, x => x / 2) } }
  const input = new Float32Array(960).fill(.5)
  const result = filterFrames(engine, input)
  assert.equal(resets, 1); assert.equal(calls, 2)
  assert.equal(result.output.length, 960); assert.ok(result.output.every(value => value === .25))
  assert.equal(result.durations.length, 2)
})

test('rejects malformed input and invalid engine output', () => {
  const engine = { reset() {}, process(frame) { return frame } }
  assert.throws(() => filterFrames(engine, new Float32Array(479)), /frames/)
  const invalid = new Float32Array(480); invalid[0] = NaN
  assert.throws(() => filterFrames(engine, invalid), /nonfinite/)
  assert.throws(() => filterFrames({ ...engine, process: () => new Float32Array(1) }, new Float32Array(480)), /output/)
  assert.throws(() => filterFrames({ ...engine, process: () => new Float32Array(480).fill(NaN) }, new Float32Array(480)), /nonfinite/)
})
