import test from 'node:test'
import assert from 'node:assert/strict'
import { deepfilterAssetsPlugin } from './deepfilter_assets.mjs'
import { fileURLToPath } from 'node:url'

test('disabled builds do not require or emit engine assets', async () => {
  const plugin = deepfilterAssetsPlugin({ enabled: false })
  await plugin.buildStart.call({})
  let emitted = 0
  await plugin.generateBundle.call({ emitFile: () => emitted++ })
  assert.equal(emitted, 0)
})

test('enabled builds reject a missing explicit bundle override', async () => {
  const bundle = fileURLToPath(new URL('./__missing_bundle_for_test__', import.meta.url))
  const plugin = deepfilterAssetsPlugin({ enabled: true, bundle })
  await assert.rejects(plugin.buildStart.call({}), /ENOENT/)
})
