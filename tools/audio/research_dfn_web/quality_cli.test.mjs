import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const harness = fileURLToPath(new URL('../quality_harness.mjs', import.meta.url))
const wrongAsset = fileURLToPath(new URL('./quality_core.mjs', import.meta.url))

test('rejects unpinned artifacts before attempting to import the glue', () => {
  const result = spawnSync(process.execPath, [harness, '--deepfilter-research', wrongAsset, wrongAsset, wrongAsset], { encoding: 'utf8' })
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /research asset checksum mismatch/)
  assert.doesNotMatch(result.stderr, /not a valid WebAssembly/)
})

test('requires exactly three research artifact paths', () => {
  const result = spawnSync(process.execPath, [harness, '--deepfilter-research', wrongAsset], { encoding: 'utf8' })
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /Provide generated JS glue, WASM and model paths/)
})
