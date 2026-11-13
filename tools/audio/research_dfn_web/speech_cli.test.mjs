import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, readFileSync, unlinkSync, rmdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

test('rejects a mismatched fixture before touching an existing output or model', () => {
  const dir = mkdtempSync(join(tmpdir(), 'boohta-dfn-speech-'))
  try {
    const input = join(dir, 'input.f32le'), output = join(dir, 'output.f32le')
    writeFileSync(input, Buffer.alloc(4)); writeFileSync(output, 'preserve')
    const runner = fileURLToPath(new URL('./speech.mjs', import.meta.url))
    const result = spawnSync(process.execPath, [runner, '--input', input, '--sha256', 'bad',
      '--output', output, '--glue', 'missing', '--wasm', 'missing', '--model', 'missing'], { encoding: 'utf8' })
    assert.notEqual(result.status, 0); assert.match(result.stderr, /input checksum mismatch/)
    assert.equal(readFileSync(output, 'utf8'), 'preserve')
  } finally {
    unlinkSync(join(dir, 'input.f32le')); unlinkSync(join(dir, 'output.f32le')); rmdirSync(dir)
  }
})
