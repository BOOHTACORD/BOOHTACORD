import test from 'node:test'
import assert from 'node:assert/strict'
import { researchAsset } from './research_assets.mjs'

test('only explicitly allowed research assets are mapped', () => {
  assert.deepEqual(researchAsset('/audio/dfn-research/dfn_bg.wasm'), ['dfn_bg.wasm', 'application/wasm'])
  assert.deepEqual(researchAsset('/audio/deepfilternet/research-d375b2d/deepfilter/core.js?x=1'), ['deepfilter/core.js', 'text/javascript'])
  for (const url of ['/audio/dfn-research/../secret', '/audio/dfn-research/%2e%2e/secret',
    '/audio/dfn-research/dfn.js', '/audio/dfn-research/deepfilter/../../secret']) {
    assert.equal(researchAsset(url), undefined)
  }
})
