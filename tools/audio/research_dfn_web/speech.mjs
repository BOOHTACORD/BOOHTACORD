/** Only explicitly licensed/consented offline fixtures, never actual calls. */
import { readFileSync, statSync, writeFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { resolve } from 'node:path'
import { processFrames } from '../speech_fixture/frames.mjs'
import { loadResearchEngine } from './load_engine.mjs'

const args = process.argv.slice(2)
if (args.length !== 12 || args[0] !== '--input' || args[2] !== '--sha256' || args[4] !== '--output' ||
    args[6] !== '--glue' || args[8] !== '--wasm' || args[10] !== '--model') throw new Error('invalid arguments')
const [inputPath, expected, outputPath, glue, wasm, model] = [args[1], args[3], args[5], args[7], args[9], args[11]]
if (resolve(inputPath) === resolve(outputPath)) throw new Error('input and output must differ')
if (statSync(inputPath).size > 100_000_000) throw new Error('invalid input length')
const bytes = readFileSync(inputPath)
if (!bytes.length || bytes.length % 4 || bytes.length > 100_000_000) throw new Error('invalid input length')
const hash = value => createHash('sha256').update(value).digest('hex')
if (hash(bytes) !== expected) throw new Error('input checksum mismatch')
const input = new Float32Array(bytes.length / 4)
for (let i = 0; i < input.length; i++) input[i] = bytes.readFloatLE(i * 4)
const { engine, hashes } = await loadResearchEngine([glue, wasm, model])
try {
  const output = processFrames(input, 480, 12, frame => engine.process(frame))
  const result = Buffer.allocUnsafe(output.length * 4)
  let peak = 0, aboveUnity = 0
  for (let i = 0; i < output.length; i++) {
    result.writeFloatLE(output[i], i * 4)
    peak = Math.max(peak, Math.abs(output[i])); if (Math.abs(output[i]) > 1) aboveUnity++
  }
  writeFileSync(outputPath, result, { flag: 'wx' })
  console.log(JSON.stringify({ status: 'RESEARCH_ONLY', inputSha256: expected, outputSha256: hash(result),
    wasmSha256: hashes[1], modelSha256: hashes[2], inputSamples: input.length, outputSamples: output.length,
    peakAbsoluteOutput: peak, outputSamplesOverUnity: aboveUnity,
    limitations: ['Offline processing only; speech quality and latency NOT_ASSESSED'] }))
} finally { engine.free() }
