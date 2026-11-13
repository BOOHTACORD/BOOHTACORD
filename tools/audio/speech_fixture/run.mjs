/** Offline research fixture. Never pass call recordings or private conversations. */
import { readFileSync, writeFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { argv } from 'node:process'
import { resolve } from 'node:path'
import { verifyAsset } from '../assets/verify.mjs'
import { processFrames } from './frames.mjs'

const args = argv.slice(2)
if (args.length !== 10 || args[0] !== '--input' || args[2] !== '--sha256' ||
    args[4] !== '--output' || args[6] !== '--asset-dir' || args[8] !== '--lock') {
  throw new Error('Expected --input <float32le> --sha256 <hash> --output <new-file> --asset-dir <dir> --lock <file>')
}
const [inputPath, expectedHash, outputPath, folder, lockPath] = [args[1], args[3], args[5], args[7], args[9]]
if (resolve(inputPath) === resolve(outputPath)) throw new Error('input and output must differ')
const hash = bytes => createHash('sha256').update(bytes).digest('hex')
const inputBytes = readFileSync(inputPath)
if (!inputBytes.length || inputBytes.length % 4 || inputBytes.length > 100_000_000) throw new Error('invalid input length')
if (hash(inputBytes) !== expectedHash) throw new Error('input checksum mismatch')
const input = new Float32Array(inputBytes.length / 4)
for (let i = 0; i < input.length; i++) input[i] = inputBytes.readFloatLE(i * 4)
const manifest = JSON.parse(readFileSync(resolve(folder, 'rnnoise-manifest.json')))
const wasm = readFileSync(resolve(folder, 'rnnoise.wasm'))
verifyAsset(manifest, wasm, JSON.parse(readFileSync(lockPath)))
const module = new WebAssembly.Module(wasm)
if (WebAssembly.Module.imports(module).length) throw new Error('unexpected WASM imports')
const dsp = new WebAssembly.Instance(module, {}).exports
dsp._initialize()
if (dsp.ns_init() !== 1) throw new Error('RNNoise initialization failed')
const source = new Float32Array(dsp.memory.buffer, dsp.ns_input(), 480)
const target = new Float32Array(dsp.memory.buffer, dsp.ns_output(), 480)
const output = processFrames(input, 480, 12, frame => {
  for (let i = 0; i < 480; i++) source[i] = Math.max(-1, Math.min(1, frame[i])) * 32768
  dsp.ns_process()
  if (!target.every(Number.isFinite)) throw new Error('nonfinite model output')
  return Float32Array.from(target, sample => Math.max(-1, Math.min(1, sample / 32768)))
})
const outputBytes = Buffer.allocUnsafe(output.length * 4)
for (let i = 0; i < output.length; i++) outputBytes.writeFloatLE(output[i], i * 4)
writeFileSync(outputPath, outputBytes, { flag: 'wx' })
console.log(JSON.stringify({ status: 'PASS', inputSha256: expectedHash, outputSha256: hash(outputBytes),
  sourceCommit: manifest.sourceCommit, modelSha256: manifest.modelSha256,
  wasmSha256: manifest.wasmSha256, inputSamples: input.length, outputSamples: output.length,
  limitations: ['Offline DSP execution only; no intelligibility, listening, or latency acceptance'] }))
