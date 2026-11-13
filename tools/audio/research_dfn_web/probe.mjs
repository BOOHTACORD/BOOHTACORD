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
console.log(JSON.stringify({ cycles: sizes.length, wasmBytes: sizes,
  ownershipProbe: 'PASS', clientIntegration: 'NOT_RUN', acousticQuality: 'NOT_ASSESSED' }))
