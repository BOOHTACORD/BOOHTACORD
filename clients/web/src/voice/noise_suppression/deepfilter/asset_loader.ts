/** Research-only identity; enabling it in a release requires a reproducible builder. */
export const researchIdentity = Object.freeze({
  path: '/audio/deepfilternet/research-d375b2d/',
  wasmSha256: '0745651e0b7a0993e8a4d71320840d28754c112425906b6f0e93f4c770724fec',
  modelSha256: 'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616',
})

async function fetchBytes(url: URL, type: string, limit: number, signal: AbortSignal): Promise<Uint8Array> {
  const response = await fetch(url, { credentials: 'same-origin', redirect: 'error', signal })
  if (!response.ok || !response.headers.get('content-type')?.includes(type) || !response.body) throw new Error('asset unavailable')
  const declared = Number(response.headers.get('content-length'))
  if (declared > limit) throw new Error('asset too large')
  const reader = response.body.getReader(), chunks: Uint8Array[] = []
  let size = 0
  try {
    for (;;) {
      const { done, value } = await reader.read()
      if (done) break
      size += value.length
      if (size > limit) throw new Error('asset too large')
      chunks.push(value)
    }
  } catch (error) { void reader.cancel().catch(() => {}); throw error }
  const bytes = new Uint8Array(size)
  let offset = 0
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length }
  return bytes
}

async function checksum(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes as Uint8Array<ArrayBuffer>)
  return Array.from(new Uint8Array(digest), value => value.toString(16).padStart(2, '0')).join('')
}

export async function loadDeepFilterAssets(timeoutMs = 15000, signal?: AbortSignal): Promise<{ module: WebAssembly.Module; model: Uint8Array }> {
  const controller = new AbortController()
  let timer: ReturnType<typeof setTimeout> | undefined
  let cancel: (() => void) | undefined
  try {
    return await Promise.race([
      (async () => {
        const root = new URL(researchIdentity.path, window.location.origin)
        const [wasm, model] = await Promise.all([
          fetchBytes(new URL('dfn_bg.wasm', root), 'application/wasm', 25_000_000, controller.signal),
          fetchBytes(new URL('model.bin', root), 'application/octet-stream', 9_000_000, controller.signal),
        ])
        const hashes = await Promise.all([checksum(wasm), checksum(model)])
        if (hashes[0] !== researchIdentity.wasmSha256 || hashes[1] !== researchIdentity.modelSha256) throw new Error('asset checksum mismatch')
        return { module: await WebAssembly.compile(wasm as Uint8Array<ArrayBuffer>), model }
      })(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(new Error('asset timeout')) }, timeoutMs)
        cancel = () => { controller.abort(); reject(new Error('asset cancelled')) }
        if (signal?.aborted) cancel(); else signal?.addEventListener('abort', cancel, { once: true })
      }),
    ])
  } finally {
    if (timer !== undefined) clearTimeout(timer)
    if (cancel) signal?.removeEventListener('abort', cancel)
    controller.abort()
  }
}
