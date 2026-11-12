import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { verifyAsset } from './verify.mjs'

test('accepts only the named version and matching WASM checksum', () => {
  const bytes = Buffer.from('fixture wasm bytes')
  const sha = createHash('sha256').update(bytes).digest('hex')
  const lock = { version: 'v0.1-cdf196b', sourceCommit: 'upstream', modelSha256: 'model' }
  const info = { ...lock, wasmSha256: sha }
  assert.doesNotThrow(() => verifyAsset(info, bytes, lock))
  assert.throws(() => verifyAsset(info, bytes, { ...lock, version: 'v0.2' }), /version/)
  assert.throws(() => verifyAsset(info, Buffer.from('altered'), lock), /checksum/)
  assert.throws(() => verifyAsset({ ...info, wasmSha256: '' }, bytes, lock), /checksum/)
  assert.throws(() => verifyAsset({ ...info, modelSha256: 'wrong' }, bytes, lock), /model/)
  assert.throws(() => verifyAsset({ ...info, sourceCommit: 'wrong' }, bytes, lock), /source/)
})
