/** Bound async preparation and release abort listeners after either outcome. */
export async function bounded<T>(promise: Promise<T>, timeoutMs: number, signal?: AbortSignal): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  let cancel: (() => void) | undefined
  try {
    return await Promise.race([promise, new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new Error('processor timeout')), timeoutMs)
      cancel = () => reject(new Error('processor cancelled'))
      if (signal?.aborted) cancel(); else signal?.addEventListener('abort', cancel, { once: true })
    })])
  } finally {
    if (timer) clearTimeout(timer)
    if (cancel) signal?.removeEventListener('abort', cancel)
  }
}
