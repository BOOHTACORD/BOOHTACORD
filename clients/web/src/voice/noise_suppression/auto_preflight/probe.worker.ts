import { benchmark } from './benchmark'

interface RnExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory
  _initialize(): void; ns_init(): number; ns_input(): number; ns_output(): number; ns_process(): number
}
type Model = { process(frame: Float32Array): Float32Array; free(): void }
declare const self: { onmessage: (event: MessageEvent) => void; postMessage(value: unknown): void }

async function open(data: { engine: string; module: WebAssembly.Module; model?: Uint8Array }): Promise<Model> {
  if (data.engine === 'rnnoise') {
    const dsp = new WebAssembly.Instance(data.module, {}).exports as RnExports
    dsp._initialize()
    if (dsp.ns_init() !== 1) throw Error('initialization')
    const input = new Float32Array(dsp.memory.buffer, dsp.ns_input(), 480)
    const output = new Float32Array(dsp.memory.buffer, dsp.ns_output(), 480)
    return { process(frame) {
      for (let i = 0; i < 480; i++) input[i] = frame[i] * 32768
      dsp.ns_process()
      for (let i = 0; i < 480; i++) frame[i] = output[i] / 32768
      return frame
    }, free() { /* Worker termination releases the independent WASM instance. */ } }
  }
  if (data.engine !== 'deepfilter' || !data.model) throw Error('unknown-engine')
  const url = '/audio/deepfilternet/research-d375b2d/deepfilter/dfn.js'
  const binding = await import(/* @vite-ignore */ url)
  binding.initSync({ module: data.module })
  return new binding.Denoiser(data.model, 25)
}

self.onmessage = async event => {
  let model: Model | undefined
  try { model = await open(event.data); self.postMessage(benchmark(frame => model!.process(frame))) }
  catch { self.postMessage({ ready: false }) }
  finally { try { model?.free() } catch { /* Termination discards trapped state. */ } }
}
