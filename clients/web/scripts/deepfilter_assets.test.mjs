import test from 'node:test'
import assert from 'node:assert/strict'
import { deepfilterAssetsPlugin } from './deepfilter_assets.mjs'

test('disabled builds do not require or emit research assets', async () => {
  const plugin = deepfilterAssetsPlugin({ enabled: false })
  await plugin.buildStart.call({})
  let emitted = 0
  await plugin.generateBundle.call({ emitFile: () => emitted++ })
  assert.equal(emitted, 0)
})

test('enabled builds fail closed when the verified bundle is absent', async () => {
  const plugin = deepfilterAssetsPlugin({ enabled: true })
  await assert.rejects(plugin.buildStart.call({}), /bundle/i)
})
