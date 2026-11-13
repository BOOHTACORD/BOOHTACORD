import { createHash } from 'node:crypto'

export function verifyAsset(manifest, bytes, lock) {
  if (manifest.version !== lock.version) throw new Error('RNNoise asset version mismatch')
  if (manifest.sourceCommit !== lock.sourceCommit) throw new Error('RNNoise source mismatch')
  if (manifest.modelSha256 !== lock.modelSha256) throw new Error('RNNoise model mismatch')
  const hash = createHash('sha256').update(bytes).digest('hex')
  if (hash !== manifest.wasmSha256) throw new Error('RNNoise WASM checksum mismatch')
}
