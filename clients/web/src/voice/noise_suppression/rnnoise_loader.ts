import { rnnoiseModels, selectRnnoiseModel, type RnnoiseModelIdentity } from './rnnoise_model'
export const RNNOISE_MANIFEST_PATH = rnnoiseModels.v01.manifestPath
export interface RnnoiseAssets { module: WebAssembly.Module; modelId: string; wasmSha256: string }
const loading = new Map<string, Promise<RnnoiseAssets>>()
export async function loadRnnoiseAssets(manifestPath?: string, timeoutMs = 8000): Promise<RnnoiseAssets> {
  const model = selectRnnoiseModel(import.meta.env.VITE_RNNOISE_V02_ENABLED)
  const expectedWasm = model === rnnoiseModels.v02 ? import.meta.env.VITE_RNNOISE_V02_WASM_SHA256 : undefined
  if (model === rnnoiseModels.v02 && (typeof expectedWasm !== 'string' || !/^[a-f0-9]{64}$/.test(expectedWasm)))
    throw new Error('RNNoise v0.2 WASM identity missing')
  const url = new URL(manifestPath ?? model.manifestPath, window.location.origin)
  if (url.origin !== window.location.origin) throw new Error('RNNoise assets must be same origin')
  const key = `${model.version}:${expectedWasm ?? ''}:${url.href}`
  let pending = loading.get(key)
  if (!pending) {
    pending = load(url, timeoutMs, model, expectedWasm)
    loading.set(key, pending)
    void pending.catch(() => { if (loading.get(key) === pending) loading.delete(key) })
  }
  return pending
}
async function load(url: URL, timeoutMs: number, model: Readonly<RnnoiseModelIdentity>, expectedWasm?: string): Promise<RnnoiseAssets> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(url, { credentials: 'same-origin', signal: controller.signal, redirect: 'error' })
    if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) throw new Error('RNNoise manifest unavailable')
    const info = await response.json()
    if (info.version !== model.version || info.sourceCommit !== model.sourceCommit || info.sourceArchiveSha256 !== model.sourceArchiveSha256 || info.modelSha256 !== model.modelSha256 ||
        info.modelId !== model.modelId || info.frameSize !== 480 || info.sampleRate !== 48000 ||
        info.pcmScale !== 32768 || info.threads !== 1 || info.simd !== false || info.wasmFile !== 'rnnoise.wasm' ||
        !/^[a-f0-9]{64}$/.test(info.wasmSha256) || (expectedWasm !== undefined && info.wasmSha256 !== expectedWasm)) throw new Error('RNNoise manifest incompatible')
    const wasmResponse = await fetch(new URL(info.wasmFile, url), { credentials: 'same-origin', signal: controller.signal, redirect: 'error' })
    if (!wasmResponse.ok || !wasmResponse.headers.get('content-type')?.includes('application/wasm')) throw new Error('RNNoise WASM unavailable')
    const bytes = await wasmResponse.arrayBuffer()
    const checksum = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), byte => byte.toString(16).padStart(2, '0')).join('')
    if (checksum !== info.wasmSha256) throw new Error('RNNoise WASM checksum mismatch')
    const module = await WebAssembly.compile(bytes)
    if (WebAssembly.Module.imports(module).length !== 0) throw new Error('RNNoise WASM requires unexpected imports')
    return { module, modelId: info.modelId, wasmSha256: checksum }
  } finally { clearTimeout(timer) }
}
