// Isolated WASM ownership probe: do not use with conversation audio.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const [gluePath, wasmPath, modelPath] = process.argv.slice(2)
if (!gluePath || !wasmPath || !modelPath || process.argv.length !== 5) {
  throw new Error('Provide generated JS glue, WASM and model paths')
}
const api = await import(pathToFileURL(resolve(gluePath)).href)
const wasm = api.initSync({ module: new WebAssembly.Module(readFileSync(resolve(wasmPath))) })
const model = readFileSync(resolve(modelPath)), sizes = []
for (let i = 0; i < 5; i++) {
  const denoiser = new api.Denoiser(model, 25)
  if (denoiser.frame_size() !== 480) throw new Error('Invalid frame size')
  for (const invalid of [new Float32Array(479), Float32Array.from({ length: 480 }, () => NaN)]) {
    let rejected = false
    try { denoiser.process(invalid) } catch { rejected = true }
    if (!rejected) throw new Error('Invalid frame accepted')
  }
  const output = denoiser.process(new Float32Array(480))
  if (output.length !== 480 || !output.every(Number.isFinite)) throw new Error('Invalid output')
  denoiser.free()
  let rejected = false
  try { denoiser.process(new Float32Array(480)) } catch { rejected = true }
  if (!rejected) throw new Error('Freed object remained usable')
  sizes.push(wasm.memory.buffer.byteLength)
}
const reset = new api.Denoiser(model, 25), fresh = new api.Denoiser(model, 25)
for (let n = 0; n < 100; n++) {
  reset.process(Float32Array.from({ length: 480 }, (_, i) => .3 * Math.sin((n * 480 + i) * .05)))
}
reset.reset()
let difference = 0
for (let n = 0; n < 200; n++) {
  const input = n < 100 ? new Float32Array(480)
    : Float32Array.from({ length: 480 }, (_, i) => .1 * Math.sin((n * 480 + i) * .07))
  const a = reset.process(input), b = fresh.process(input)
  for (let i = 0; i < 480; i++) difference = Math.max(difference, Math.abs(a[i] - b[i]))
}
reset.free(); fresh.free()
if (difference > 1e-6) throw new Error('Reset differs from fresh model')
console.log(JSON.stringify({ cycles: sizes.length, wasmBytes: sizes,
  ownershipProbe: 'PASS', resetMaxDifference: difference,
  clientIntegration: 'NOT_RUN', acousticQuality: 'NOT_ASSESSED' }))
