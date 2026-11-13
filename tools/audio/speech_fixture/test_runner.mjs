import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, readFileSync, unlinkSync, rmdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

test('rejects an incorrect input hash before touching an existing output', () => {
  const dir = mkdtempSync(join(tmpdir(), 'boohta-audio-'))
  try {
    const input = join(dir, 'input.f32le'), output = join(dir, 'output.f32le')
    writeFileSync(input, Buffer.alloc(4))
    writeFileSync(output, 'preserve')
    const runner = fileURLToPath(new URL('./run.mjs', import.meta.url))
    const result = spawnSync(process.execPath, [runner, '--input', input, '--sha256', 'bad',
      '--output', output, '--asset-dir', dir, '--lock', join(dir, 'missing')], { encoding: 'utf8' })
    assert.notEqual(result.status, 0)
    assert.match(result.stderr, /input checksum mismatch/)
    assert.equal(readFileSync(output, 'utf8'), 'preserve')
  } finally {
    unlinkSync(join(dir, 'input.f32le'))
    unlinkSync(join(dir, 'output.f32le'))
    rmdirSync(dir)
  }
})
