export type CustomLoader = (id: string, signal: AbortSignal) => Promise<Uint8Array>

export async function boundedCustom(load: CustomLoader, id: string, parent: AbortSignal, deadline: number): Promise<Uint8Array | null> {
  const child = new AbortController()
  let timer: ReturnType<typeof setTimeout> | undefined
  let abort!: () => void
  const timeout = new Promise<null>(resolve => {
    timer = setTimeout(() => { child.abort(); resolve(null) }, deadline)
    abort = () => { child.abort(); resolve(null) }
    parent.addEventListener('abort', abort, { once: true })
  })
  try {
    if (parent.aborted) return null
    const bytes = await Promise.race([load(id, child.signal).catch(() => null), timeout])
    return bytes instanceof Uint8Array && bytes.byteLength > 0 && bytes.byteLength <= 256 * 1024 ? bytes : null
  } catch { return null }
  finally { if (timer !== undefined) clearTimeout(timer); parent.removeEventListener('abort', abort) }
}
