import type { RealtimeConnectOptions } from './realtime_connection_types'

export function boundedSessionCheck(check: (signal: AbortSignal) => Promise<boolean>) {
  const controller = new AbortController()
  let release!: () => void
  const cancelled = new Promise<null>(resolve => { release = () => resolve(null) })
  const cancel = () => { controller.abort(); release() }
  const timer = setTimeout(cancel, 10_000)
  let work: Promise<boolean>
  try { work = check(controller.signal) } catch (error) { work = Promise.reject(error) }
  const result = Promise.race([work, cancelled]).finally(() => clearTimeout(timer))
  return { result, cancel }
}

export function createSocketAttempt(options: RealtimeConnectOptions) {
  let open = false
  let deadline: ReturnType<typeof setTimeout> | null = null
  function clear(): void { if (deadline !== null) clearTimeout(deadline); deadline = null }
  return {
    begin(): void { if (!open) { open = true; options.onSocketStart?.() } },
    arm(timeout: () => void): void { clear(); deadline = setTimeout(timeout, 15_000) },
    ready: clear,
    end(): void { clear(); if (open) { open = false; options.onSocketEnd?.() } },
  }
}
