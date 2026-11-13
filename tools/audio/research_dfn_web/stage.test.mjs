import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { expected, stage } from './stage.mjs'
import { fileURLToPath } from 'node:url'

test('rejects an existing destination without changing it', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dfn-stage-'))
  try {
    const output = join(root, 'existing'); await mkdir(output)
    await writeFile(join(output, 'marker'), 'keep')
    await assert.rejects(stage({ bundle: join(root, 'missing'), output }))
    assert.equal(await readFile(join(output, 'marker'), 'utf8'), 'keep')
  } finally { await rm(root, { recursive: true, force: true }) }
})

test('rejects a tampered artifact before creating a destination', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dfn-stage-'))
  try {
    const bundle = join(root, 'bundle'), output = join(root, 'new')
    await mkdir(bundle)
    for (const name of ['dfn_bg.wasm', 'dfn.js', 'model.bin']) await writeFile(join(bundle, name), 'bad')
    await assert.rejects(stage({ bundle, output }), /checksum/)
    await assert.rejects(readFile(join(output, 'model.bin')), { code: 'ENOENT' })
  } finally { await rm(root, { recursive: true, force: true }) }
})

test('staging hashes agree with the actual runtime loader', async () => {
  const loader = await readFile(fileURLToPath(new URL('../../../clients/web/src/voice/noise_suppression/deepfilter/asset_loader.ts', import.meta.url)), 'utf8')
  assert.ok(loader.includes(expected['dfn_bg.wasm']))
  assert.ok(loader.includes(expected['model.bin']))
})
