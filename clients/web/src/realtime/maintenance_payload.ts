const generationId = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function validMaintenanceRealtime(kind: string, payload: Record<string, unknown>): boolean {
  if (kind !== 'maintenance.snapshot' && kind !== 'maintenance.changed') return true
  return Object.keys(payload).sort().join(',') === 'active,generation,revision,version' &&
    payload.version === 1 && typeof payload.generation === 'string' && generationId.test(payload.generation) &&
    Number.isSafeInteger(payload.revision) && Number(payload.revision) >= 1 && typeof payload.active === 'boolean'
}
