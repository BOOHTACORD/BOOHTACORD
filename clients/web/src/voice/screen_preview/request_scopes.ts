import type { ScreenPreviewRequest } from './client'

export class ScreenPreviewRequestScopes {
  private active = new Set<AbortController>()

  constructor(private readonly send: ScreenPreviewRequest) {}

  create() {
    const controller = new AbortController()
    this.active.add(controller)
    let released = false
    return {
      request: (input: string, init: RequestInit) => this.send.call(globalThis, input, { ...init, signal: controller.signal }),
      abort: () => controller.abort(),
      release: () => { if (!released) { released = true; this.active.delete(controller) } },
    }
  }

  abortAll(): void {
    for (const controller of this.active) controller.abort()
    this.active.clear()
  }
}
