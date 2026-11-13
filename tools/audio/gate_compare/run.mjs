// Offline comparison only: input audio remains on the operator's machine.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { MicrophoneDsp as Current } from '../../../clients/web/src/voice/microphone_processing/dsp.ts'

const [baselinePath, inputDir] = process.argv.slice(2)
if (!baselinePath || !inputDir || process.argv.length !== 4) {
  throw new Error('Provide baseline DSP .mts and a directory containing clip-01..08.f32le')
}
const { MicrophoneDsp: Baseline } = await import(pathToFileURL(resolve(baselinePath)).href)
const transitions = [], energy = { baseline: 0, current: 0 }, options = { vadThresholdDb: -50, microphoneGainPercent: 100 }
let count = 0
for (let i = 1; i <= 8; i++) {
  const data = readFileSync(resolve(inputDir, `clip-${String(i).padStart(2, '0')}.f32le`))
  if (!data.length || data.length % 4) throw new Error('Invalid float32 input length')
  const input = new Float32Array(data.length / 4)
  for (let j = 0; j < input.length; j++) input[j] = data.readFloatLE(j * 4)
  if (!input.every(Number.isFinite)) throw new Error('Input contains nonfinite samples')
  const inputRms = Math.sqrt(input.reduce((sum, value) => sum + value * value, 0) / input.length)
  if (!inputRms) throw new Error('Silent input cannot be normalized')
  const scale = 10 ** (-45 / 20) / inputRms
  const baseline = new Baseline(48000), current = new Current(48000)
  baseline.configure(options, true, false); current.configure(options, true, false)
  let previous = { baseline: 0, current: 0 }, previousGate = false
  for (let offset = 0; offset < input.length; offset += 480) {
    const frame = Float32Array.from(input.subarray(offset, offset + 480), value => value * scale)
    const a = new Float32Array(frame.length), b = new Float32Array(frame.length)
    baseline.process(frame, a); current.process(frame, b)
    if (baseline.gateOpen !== current.gateOpen) throw new Error('Gate decisions differ')
    if (previousGate && !baseline.gateOpen) transitions.push({
      baseline: Math.abs(a[0] - previous.baseline), current: Math.abs(b[0] - previous.current),
    })
    for (let j = 0; j < frame.length; j++) { energy.baseline += a[j] ** 2; energy.current += b[j] ** 2; count++ }
    previous = { baseline: a.at(-1), current: b.at(-1) }; previousGate = baseline.gateOpen
  }
}
const max = key => Math.max(0, ...transitions.map(row => row[key]))
const mean = key => transitions.reduce((sum, row) => sum + row[key], 0) / Math.max(1, transitions.length)
console.log(JSON.stringify({ samples: count, closingTransitions: transitions.length,
  closingJumpMax: { baseline: max('baseline'), current: max('current') },
  closingJumpMean: { baseline: mean('baseline'), current: mean('current') },
  outputRms: { baseline: Math.sqrt(energy.baseline / count), current: Math.sqrt(energy.current / count) },
  acousticQuality: 'NOT_ASSESSED' }))
