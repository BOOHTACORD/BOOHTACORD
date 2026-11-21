import { createProtectedRefreshGate } from './gate'
import { coalesceStores } from './stores'
import type { WorkspaceRealtimeStores } from './types'

export function createProtectedRefreshScope(original: WorkspaceRealtimeStores) {
  let gate = createProtectedRefreshGate()
  return {
    renew(): WorkspaceRealtimeStores {
      gate.close()
      gate = createProtectedRefreshGate()
      return coalesceStores(original, gate)
    },
    close(): void { gate.close() },
  }
}
