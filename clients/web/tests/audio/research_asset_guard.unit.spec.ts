import { afterEach, expect, it } from 'vitest'
import { mkdtempSync, mkdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { rnnoiseV02ReleaseGuard } from '../../scripts/research_asset_guard.mjs'

const roots: string[] = []
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }) })
function root() { const path = mkdtempSync(join(tmpdir(), 'rnnoise-v02-guard-')); roots.push(path); return path }

it('rejects a production build with experimental RNNoise enabled', () => {
  const guard = rnnoiseV02ReleaseGuard({ command: 'build', enabled: true, publicDir: root() })
  expect(() => guard.buildStart()).toThrow(/RNNoise v0.2.*research/i)
})

it('rejects a production build containing even disabled research assets', () => {
  const publicDir = root()
  mkdirSync(join(publicDir, 'audio', 'rnnoise', 'v0.2-904a876'), { recursive: true })
  const guard = rnnoiseV02ReleaseGuard({ command: 'build', enabled: false, publicDir })
  expect(() => guard.buildStart()).toThrow(/RNNoise v0.2.*research/i)
})

it('allows ordinary builds and local research development', () => {
  const publicDir = root()
  expect(() => rnnoiseV02ReleaseGuard({ command: 'build', enabled: false, publicDir }).buildStart()).not.toThrow()
  mkdirSync(join(publicDir, 'audio', 'rnnoise', 'v0.2-904a876'), { recursive: true })
  expect(() => rnnoiseV02ReleaseGuard({ command: 'serve', enabled: true, publicDir }).buildStart()).not.toThrow()
})
