import { ref } from 'vue'
import { validMaintenanceRealtime } from '../realtime/maintenance_payload'

type MaintenanceEvent = { kind: string; payload: Record<string, unknown> }

export function createMaintenanceState() {
  const active = ref(false)
  const known = ref(false)
  let owner = 0
  let initialized = false
  let generation: string | null = null
  let revision = 0

  function begin(): number {
    initialized = false
    known.value = false
    return ++owner
  }

  function accept(token: number, event: MaintenanceEvent): boolean {
    if (token !== owner || !['maintenance.snapshot', 'maintenance.changed'].includes(event.kind) || !validMaintenanceRealtime(event.kind, event.payload)) return false
    const nextGeneration = event.payload.generation as string
    const nextRevision = event.payload.revision as number
    if (!initialized) {
      if (event.kind !== 'maintenance.snapshot' || (generation === nextGeneration && (nextRevision < revision || (nextRevision === revision && event.payload.active !== active.value)))) return false
    } else if (event.kind !== 'maintenance.changed' || generation !== nextGeneration || nextRevision <= revision) return false
    generation = nextGeneration
    revision = nextRevision
    initialized = true
    active.value = event.payload.active as boolean
    known.value = true
    return true
  }

  function disconnected(token: number): void {
    if (token !== owner) return
    owner++
    initialized = false
    known.value = false
  }

  return { active, known, begin, accept, disconnected }
}
