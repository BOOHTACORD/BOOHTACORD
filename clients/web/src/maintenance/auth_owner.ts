import type { createMaintenanceState } from './state'

type Event = { kind: string; payload: Record<string, unknown> }

export function createAuthenticatedMaintenance(state: ReturnType<typeof createMaintenanceState>) {
  let token = 0, initialized = false
  return {
    start(): void { token = state.begin(); initialized = false },
    stop(): void { state.disconnected(token); initialized = false },
    accept(event: Event): boolean {
      if (event.kind !== 'maintenance.snapshot' && event.kind !== 'maintenance.changed') return false
      const applied = state.accept(token, event)
      if (!applied && (!initialized || event.kind === 'maintenance.snapshot')) throw new Error('Invalid maintenance snapshot')
      if (applied) initialized = true
      return true
    },
  }
}
