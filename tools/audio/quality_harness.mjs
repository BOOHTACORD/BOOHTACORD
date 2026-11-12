/** Scalar DSP synthetic regression gate. Hardware/hearing gates remain NOT_RUN. */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'
import { performance } from 'node:perf_hooks'
import { argv } from 'node:process'
import { syntheticPcm, rms } from './synthetic_pcm_fixtures.mjs'
import { validateCorpus } from './corpus/manifest.mjs'
import { verifyAsset } from './assets/verify.mjs'
import { assetOptions } from './assets/options.mjs'
const corpus = JSON.parse(readFileSync(new URL('./corpus/synthetic-v1.json', import.meta.url)))
validateCorpus(corpus)
const root = fileURLToPath(new URL('../../', import.meta.url))
const { folder, lockPath } = assetOptions(argv.slice(2), root)
const manifest = JSON.parse(readFileSync(resolve(folder, 'rnnoise-manifest.json')))
const wasm = readFileSync(resolve(folder, 'rnnoise.wasm'))
const lock = JSON.parse(readFileSync(lockPath))
verifyAsset(manifest, wasm, lock)
const dsp = new WebAssembly.Instance(new WebAssembly.Module(wasm), {}).exports
dsp._initialize(); if (dsp.ns_init() !== 1) throw new Error('RNNoise init failed')
const input = new Float32Array(dsp.memory.buffer, dsp.ns_input(), 480), output = new Float32Array(dsp.memory.buffer, dsp.ns_output(), 480)
const durations = []
function process(signal) {
  if (signal.length % 480) throw new Error('Fixture must use complete frames')
  dsp.ns_reset(); const result = new Float32Array(signal.length)
  for (let offset = 0; offset < signal.length; offset += 480) {
    for (let i = 0; i < 480; i++) input[i] = Math.max(-1, Math.min(1, Number.isFinite(signal[offset + i]) ? signal[offset + i] : 0)) * 32768
    const start = performance.now(); dsp.ns_process(); durations.push(performance.now() - start)
    for (let i = 0; i < 480; i++) result[offset + i] = Math.max(-1, Math.min(1, output[i] / 32768))
  }
  if (!result.every(value => Number.isFinite(value) && Math.abs(value) <= 1)) throw new Error('Invalid PCM output')
  return result
}
const fixtures = syntheticPcm(), filteredNoise = process(fixtures.noise), filteredClean = process(fixtures.clean), filteredMixed = process(fixtures.mixed)
const deterministic = process(fixtures.mixed)
if (!filteredMixed.every((value, i) => value === deterministic[i])) throw new Error('Reset changed deterministic output')
const zeros = process(new Float32Array(480 * 100))
if (zeros.some(value => value !== 0)) throw new Error('Silence produced nonzero output')
const offset = 48000, reduction = 20 * Math.log10(rms(filteredNoise, offset) / rms(fixtures.noise, offset))
if (!(reduction < 0)) throw new Error('Stock model synthetic stationary-noise regression')
let bestLag = 0, bestScore = -Infinity
// Sparse correlation bounds deterministic CPU cost. Diagnostic only: no speech/physical latency claim.
for (let lag = 0; lag <= 1920; lag++) {
  let score = 0
  for (let i = offset; i < filteredClean.length - 1920; i += 16) score += fixtures.clean[i] * filteredClean[i + lag]
  if (score > bestScore) { bestScore = score; bestLag = lag }
}
durations.sort((a, b) => a - b)
console.log(JSON.stringify({ status: 'PASS', fixtureLicense: 'CC0-1.0 authored synthetic source', corpus, sourceCommit: manifest.sourceCommit,
  modelSha256: manifest.modelSha256, wasmSha256: manifest.wasmSha256, samplesPerSignal: fixtures.clean.length,
  measuredResults: { syntheticNoiseRmsRatioDb: reduction, syntheticCorrelationLagSamples: bestLag,
    syntheticCoreLagMs: bestLag / 48, nodeFrameCpuP99Ms: durations[Math.floor(durations.length * 0.99)] },
  limitations: ['Synthetic stationary signal only; no acoustic quality acceptance', 'Node CPU is not AudioWorklet render callback timing',
    'Browser capture NS baseline, clean Russian speech, listener preference, physical AEC, Bluetooth and 10/20 sender load NOT_RUN'] }, null, 2))
