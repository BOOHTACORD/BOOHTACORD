import { test } from 'node:test'
import assert from 'node:assert/strict'
import { processFrames } from './frames.mjs'

test('processes a full signal with padding and a fixed tail exactly once', () => {
  const input = new Float32Array([0.25, -0.5, 0.75, 0.125, -0.25])
  const calls = []
  const output = processFrames(input, 4, 1, frame => {
    calls.push(Array.from(frame))
    return Float32Array.from(frame, value => value * 2)
  })
  assert.deepEqual(calls, [[0.25, -0.5, 0.75, 0.125], [-0.25, 0, 0, 0], [0, 0, 0, 0]])
  assert.deepEqual(Array.from(output), [0.5, -1, 1.5, 0.25, -0.5, 0, 0, 0, 0, 0, 0, 0])
})

test('rejects nonfinite input and malformed processor output', () => {
  assert.throws(() => processFrames(new Float32Array([NaN]), 4, 0, x => x), /nonfinite/)
  assert.throws(() => processFrames(new Float32Array([0]), 4, 0, () => new Float32Array(3)), /frame/)
  assert.throws(() => processFrames(new Float32Array([0]), 4, 0, () => new Float32Array([NaN, 0, 0, 0])), /nonfinite/)
})
