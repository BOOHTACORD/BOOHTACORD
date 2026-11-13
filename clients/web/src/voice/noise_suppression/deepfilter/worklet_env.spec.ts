import { expect, it } from 'vitest'
import { releaseEntropy, setEntropy, withEntropy, takeEntropy } from './worklet_env.js'

it('requires a bounded entropy buffer and erases it when released', () => {
  expect(() => setEntropy(new Uint8Array(8))).toThrow('entropy unavailable')
  const bytes = new Uint8Array(65536).fill(123)
  const token = setEntropy(bytes)
  expect(token).toBe(bytes)
  releaseEntropy(token)
  expect(bytes.every(value => value === 0)).toBe(true)
})

it('keeps concurrent processor entropy independent and fails closed on exhaustion', () => {
  const first = setEntropy(new Uint8Array(65536).fill(1))
  const second = setEntropy(new Uint8Array(65536).fill(2))
  expect(() => takeEntropy(new Uint8Array(1))).toThrow('entropy unavailable')
  expect(withEntropy(first, () => takeEntropy(new Uint8Array(2)))).toEqual(new Uint8Array([1, 1]))
  expect(withEntropy(second, () => takeEntropy(new Uint8Array(2)))).toEqual(new Uint8Array([2, 2]))
  expect(withEntropy(first, () => takeEntropy(new Uint8Array(65534)))[0]).toBe(1)
  expect(() => withEntropy(first, () => takeEntropy(new Uint8Array(1)))).toThrow('entropy exhausted')
  expect(withEntropy(second, () => takeEntropy(new Uint8Array(1)))[0]).toBe(2)
  releaseEntropy(first); releaseEntropy(second)
  expect(() => withEntropy(first, () => takeEntropy(new Uint8Array(1)))).toThrow('entropy unavailable')
})
