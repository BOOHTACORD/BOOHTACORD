import assert from 'node:assert/strict'
import { cp, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import test from 'node:test'
import { readProductionAssets, assetRoot } from './bundle.mjs'

test('ordinary assets contain the verified release model and both notices', async () => {
  const assets = await readProductionAssets()
  const rnnoise = JSON.parse(assets.get('rnnoise/rnnoise-manifest.json'))
  assert.equal(rnnoise.modelId, 'rnnoise-release-v0.2')
  assert.equal(rnnoise.buildKind, 'production')
  assert.ok(assets.get('rnnoise/LICENSE-RNNoise-0.2.txt').includes('Redistribution'))
  assert.ok(assets.get('deepfilter/THIRD-PARTY-NOTICES.txt').includes('Permission is hereby granted'))
  assert.equal(JSON.parse(assets.get('deepfilter/engine.json')).unresolved.length, 0)
})

for (const file of ['rnnoise/rnnoise.wasm', 'deepfilter/dfn_bg.wasm',
  'deepfilter/model.bin', 'deepfilter/THIRD-PARTY-NOTICES.txt']) {
  test(`corrupt ${file} prevents production delivery`, async t => {
    const root = await mkdtemp(join(tmpdir(), 'boohta-assets-test-'))
    t.after(async () => {
      assert.equal(dirname(resolve(root)), resolve(tmpdir()))
      assert.ok(root.includes('boohta-assets-test-'))
      await rm(root, { recursive: true, force: true })
    })
    await cp(assetRoot, root, { recursive: true })
    const target = join(root, file)
    const bytes = await readFile(target)
    bytes[0] ^= 1
    await writeFile(target, bytes)
    await assert.rejects(readProductionAssets(root), /checksum/)
  })
}
