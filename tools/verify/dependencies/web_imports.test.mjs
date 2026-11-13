import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { importsOf } from './web_imports.mjs'

test('web image includes the Vite asset import chain', () => {
  const root = new URL('../../../', import.meta.url)
  const dockerfile = readFileSync(new URL('clients/web/Dockerfile', root), 'utf8')
  for (const [source, destination] of [
    ['clients/web/scripts/deepfilter_assets.mjs', './scripts/deepfilter_assets.mjs'],
    ['tools/audio/research_dfn_web/stage.mjs', '/app/tools/audio/research_dfn_web/stage.mjs'],
  ]) {
    assert.ok(readFileSync(new URL(source, root)).length > 0)
    assert.ok(dockerfile.split(/\r?\n/).includes(`COPY ${source} ${destination}`))
  }
})

test('compiler imports include type, re-export and dynamic imports', () => {
  assert.deepEqual(importsOf(`import type { X } from './types'
    export { x } from './public'; const lazy = import('./lazy')`, 'module.ts'), ['./types', './public', './lazy'])
})
test('strings and comments are not dependency edges', () => {
  assert.deepEqual(importsOf(`// import X from './comment'
    const assertion = "@import './design/file.css'";`, 'test.ts'), [])
})
test('Vue scripts are parsed independently of the template', () => {
  assert.deepEqual(importsOf(`<script setup lang="ts">import Header from './Header.vue'</script>
    <template>import './not-code'</template>`, 'Panel.vue'), ['./Header.vue'])
})
