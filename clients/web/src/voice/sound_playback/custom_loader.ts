import { apiBaseUrl } from '../../config/runtime'

type Request = (url: string, init: RequestInit) => Promise<Response>
const limit = 256 * 1024
const resourceId = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export async function loadJoinSound(id: string, signal: AbortSignal, request: Request = fetch): Promise<Uint8Array> {
  if (!resourceId.test(id)) throw new Error('Invalid sound identifier')
  const response = await request(`${apiBaseUrl}/voice/join-sounds/${id}`, { credentials: 'same-origin', redirect: 'error', cache: 'no-store', signal, headers: { accept: 'audio/mpeg' } })
  const length = response.headers.get('content-length')
  if (!response.ok || response.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'audio/mpeg' || response.headers.get('x-content-type-options')?.toLowerCase() !== 'nosniff' || (length !== null && (!/^\d+$/.test(length) || Number(length) > limit))) {
    await response.body?.cancel().catch(() => {})
    throw new Error('Sound unavailable')
  }
  const reader = response.body?.getReader()
  if (!reader) throw new Error('Sound unavailable')
  const chunks: Uint8Array[] = []
  let total = 0
  try {
    while (true) {
      const part = await reader.read()
      if (part.done) break
      total += part.value.byteLength
      if (total > limit || signal.aborted) throw new Error('Sound unavailable')
      chunks.push(part.value)
    }
    if (!total || signal.aborted) throw new Error('Sound unavailable')
    const result = new Uint8Array(total)
    let offset = 0
    for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.byteLength }
    return result
  } catch (error) { await reader.cancel().catch(() => {}); throw error }
  finally { reader.releaseLock() }
}
