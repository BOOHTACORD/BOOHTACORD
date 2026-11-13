/** Synthetic offline comparison only; do not use microphone or call audio. */
import { readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { filterFrames } from './quality_core.mjs'
import { rms, syntheticPcm } from '../synthetic_pcm_fixtures.mjs'
import { validateCorpus } from '../corpus/manifest.mjs'

const args = process.argv.slice(3)
if (args.length !== 3) throw new Error('Provide generated JS glue, WASM and model paths')
const expected = [
  '1e6adbcb777c92a03b09051f8f43b76a382f3e0489e4ff38ec4a9ebbbae75979',
  '0745651e0b7a0993e8a4d71320840d28754c112425906b6f0e93f4c770724fec',
  'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616',
]
const bytes = args.map(path => readFileSync(path))
const corpus = JSON.parse(readFileSync(new URL('../corpus/synthetic-v1.json', import.meta.url)))
validateCorpus(corpus)
const hashes = bytes.map(value => createHash('sha256').update(value).digest('hex'))
if (hashes.some((value, index) => value !== expected[index])) throw new Error('research asset checksum mismatch')
const api = await import(`data:text/javascript;base64,${bytes[0].toString('base64')}`)
api.initSync({ module: new WebAssembly.Module(bytes[1]) })
const engine = new api.Denoiser(bytes[2], 25)
try {
  if (engine.frame_size() !== 480) throw new Error('unexpected frame size')
  const signals = syntheticPcm()
  const noise = filterFrames(engine, signals.noise)
  const clean = filterFrames(engine, signals.clean)
  const mixed = filterFrames(engine, signals.mixed)
  const repeated = filterFrames(engine, signals.mixed)
  if (!mixed.output.every((value, i) => value === repeated.output[i])) throw new Error('reset changed output')
  let clippedSamples = 0, peak = 0
  for (const result of [noise, clean, mixed]) for (const sample of result.output) {
    const magnitude = Math.abs(sample); peak = Math.max(peak, magnitude)
    if (magnitude > 1) clippedSamples++
  }
  const durations = [...noise.durations, ...clean.durations, ...mixed.durations, ...repeated.durations].sort((a, b) => a - b)
  const offset = 48000
  let lag = 0, best = -Infinity
  for (let candidate = 0; candidate <= 1920; candidate++) {
    let score = 0
    for (let i = offset; i < signals.clean.length - 1920; i += 16) score += signals.clean[i] * clean.output[i + candidate]
    if (score > best) { best = score; lag = candidate }
  }
  console.log(JSON.stringify({ status: 'RESEARCH_ONLY', engine: 'DeepFilterNet3', corpus, wasmSha256: hashes[1], modelSha256: hashes[2],
    samplesPerSignal: signals.clean.length, syntheticNoiseRmsRatioDb: 20 * Math.log10(rms(noise.output, offset) / rms(signals.noise, offset)),
    syntheticCorrelationLagSamples: lag, peakAbsoluteOutput: peak, outputSamplesOverUnity: clippedSamples,
    nodeFrameCpuP99Ms: durations[Math.floor(durations.length * .99)],
    limitations: ['Synthetic signals only; acoustic quality NOT_ASSESSED', 'Node timing is not callback timing or end-to-end latency'] }, null, 2))
} finally { engine.free() }
