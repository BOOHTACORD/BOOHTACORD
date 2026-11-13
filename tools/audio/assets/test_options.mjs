import { test } from 'node:test'
import assert from 'node:assert/strict'
import { resolve } from 'node:path'
import { assetOptions } from './options.mjs'

test('uses the pinned baseline by default and supports an explicit pair', () => {
  const root = resolve('example')
  assert.deepEqual(assetOptions([], root), {
    folder: resolve(root, 'clients/web/public/audio/rnnoise/v0.1-cdf196b'),
    lockPath: resolve(root, 'tools/audio/rnnoise_build_lock.json'),
  })
  assert.deepEqual(assetOptions(['--asset-dir', 'fixture', '--lock', 'lock.json'], root), {
    folder: resolve('fixture'), lockPath: resolve('lock.json'),
  })
})

test('rejects a partial or ambiguous asset selection', () => {
  for (const args of [['--asset-dir', 'fixture'], ['--lock', 'lock.json'],
    ['--asset-dir', 'fixture', '--lock'], ['--asset-dir', 'fixture', '--lock', 'lock.json', 'extra']]) {
    assert.throws(() => assetOptions(args, resolve('.')), /asset-dir.*lock/)
  }
})
