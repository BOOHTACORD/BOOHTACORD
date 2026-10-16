import assert from 'node:assert/strict'
import test from 'node:test'
import { releaseMetadata } from './publish.mjs'

test('describes the exact Windows release without claiming a signature', () => {
  const metadata = releaseMetadata('windows-v1.0.26')
  assert.equal(metadata.title, 'BOOHTACORD Windows 1.0.26')
  assert.match(metadata.body, /artifact-manifest\.json/)
  assert.match(metadata.body, /Setup\.exe/)
  assert.match(metadata.body, /per-user/)
  assert.doesNotMatch(metadata.body, /signed/i)
})

test('rejects another platform tag', () => {
  assert.throws(() => releaseMetadata('android-v1.0.26'), /tag/)
})
