import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describeSyntheticCorpus, validateCorpus } from './manifest.mjs'

test('synthetic corpus has reproducible, distinct 48 kHz PCM identities', () => {
  const first = describeSyntheticCorpus()
  assert.deepEqual(first, describeSyntheticCorpus())
  assert.equal(first.sampleRate, 48000)
  assert.equal(first.sampleFormat, 'float32le')
  assert.equal(first.license, 'CC0-1.0')
  assert.equal(new Set(first.signals.map(signal => signal.sha256)).size, 3)
  assert.ok(first.signals.every(signal => signal.samples === 144000 && /^[0-9a-f]{64}$/.test(signal.sha256)))
  assert.doesNotThrow(() => validateCorpus(first))
})

test('corpus validation rejects an altered signal identity', () => {
  const manifest = describeSyntheticCorpus()
  manifest.signals[0].sha256 = '0'.repeat(64)
  assert.throws(() => validateCorpus(manifest), /corpus mismatch/)
})

test('corpus validation is independent of JSON property order', () => {
  const manifest = describeSyntheticCorpus()
  const reordered = Object.fromEntries(Object.entries(manifest).reverse())
  assert.doesNotThrow(() => validateCorpus(reordered))
})

test('generated corpus matches the checked-in reference', () => {
  const reference = JSON.parse(readFileSync(new URL('./synthetic-v1.json', import.meta.url)))
  assert.doesNotThrow(() => validateCorpus(reference))
})
