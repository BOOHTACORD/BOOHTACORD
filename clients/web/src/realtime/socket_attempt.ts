import type { RealtimeConnectOptions } from './realtime_connection_types'

export function createSocketAttempt(options: RealtimeConnectOptions) {
  let open = false
  return {
    begin(): void { if (!open) { open = true; options.onSocketStart?.() } },
    end(): void { if (open) { open = false; options.onSocketEnd?.() } },
  }
}
