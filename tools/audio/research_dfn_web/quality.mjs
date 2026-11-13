/** Synthetic offline comparison only; do not use microphone or call audio. */
import { readFileSync } from 'node:fs'
import { filterFrames } from './quality_core.mjs'
import { loadResearchEngine } from './load_engine.mjs'
import { rms, syntheticPcm } from '../synthetic_pcm_fixtures.mjs'
import { validateCorpus } from '../corpus/manifest.mjs'

const args = process.argv.slice(3)
const corpus = JSON.parse(readFileSync(new URL('../corpus/synthetic-v1.json', import.meta.url)))
validateCorpus(corpus)
const { engine, hashes } = await loadResearchEngine(args)
try {
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
