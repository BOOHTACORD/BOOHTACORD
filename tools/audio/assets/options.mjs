import { resolve } from 'node:path'

export function assetOptions(args, root) {
  if (args.length === 0) return {
    folder: resolve(root, 'clients/web/public/audio/rnnoise/v0.1-cdf196b'),
    lockPath: resolve(root, 'tools/audio/rnnoise_build_lock.json'),
  }
  if (args.length !== 4 || args[0] !== '--asset-dir' || !args[1] ||
      args[2] !== '--lock' || !args[3] || args[1].startsWith('--') || args[3].startsWith('--')) {
    throw new Error('Provide both --asset-dir <path> and --lock <path>')
  }
  return { folder: resolve(args[1]), lockPath: resolve(args[3]) }
}
