import { createHash } from 'node:crypto'
import { isDeepStrictEqual } from 'node:util'
import { syntheticPcm } from '../synthetic_pcm_fixtures.mjs'

function signalIdentity(name, samples) {
  const bytes = Buffer.allocUnsafe(samples.length * 4)
  for (let i = 0; i < samples.length; i++) bytes.writeFloatLE(samples[i], i * 4)
  return { name, samples: samples.length, sha256: createHash('sha256').update(bytes).digest('hex') }
}

export function describeSyntheticCorpus() {
  const fixture = syntheticPcm()
  return {
    version: 1, license: 'CC0-1.0', sampleRate: fixture.sampleRate,
    sampleFormat: 'float32le', normalization: 'none; fixed source amplitude',
    signals: ['noise', 'clean', 'mixed'].map(name => signalIdentity(name, fixture[name])),
  }
}

export function validateCorpus(expected) {
  if (!isDeepStrictEqual(expected, describeSyntheticCorpus())) {
    throw new Error('synthetic corpus mismatch')
  }
}
