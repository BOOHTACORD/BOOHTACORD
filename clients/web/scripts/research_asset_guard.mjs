import { lstatSync } from 'node:fs'
import { join } from 'node:path'

/** Keep unlicensed research assets out of production builds. */
export function rnnoiseV02ReleaseGuard({ command, enabled, publicDir }) {
  return {
    name: 'rnnoise-v02-release-guard',
    buildStart() {
      if (command !== 'build') return
      let present = false
      try { lstatSync(join(publicDir, 'audio', 'rnnoise', 'v0.2-904a876')); present = true }
      catch (error) { if (error?.code !== 'ENOENT') throw error }
      if (enabled || present) throw new Error('RNNoise v0.2 research assets are not approved for production builds')
    },
  }
}
