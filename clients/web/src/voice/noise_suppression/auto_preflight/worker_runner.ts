import { eligible } from './benchmark'
export interface ProbeWorker {
  postMessage(value: unknown): void
  terminate(): void
  onmessage: ((event: MessageEvent) => void) | null
  onerror: ((event: ErrorEvent) => void) | null
  onmessageerror: ((event: MessageEvent) => void) | null
}

export async function runWorker(payload: unknown, create: () => ProbeWorker, timeoutMs = 2000): Promise<boolean> {
  let worker: ProbeWorker | undefined, timer: ReturnType<typeof setTimeout> | undefined
  try {
    worker = create()
    return await new Promise<boolean>(resolve => {
      timer = setTimeout(() => resolve(false), timeoutMs)
      worker!.onmessage = event => resolve(eligible(event.data))
      worker!.onerror = () => resolve(false)
      worker!.onmessageerror = () => resolve(false)
      worker!.postMessage(payload)
    })
  } catch { return false }
  finally {
    if (timer !== undefined) clearTimeout(timer)
    if (worker) { worker.onmessage = worker.onerror = worker.onmessageerror = null; worker.terminate() }
  }
}
