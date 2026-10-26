const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
export function validNotificationRealtime(kind: string, p: Record<string, unknown>): boolean {
  if (kind === 'notification.preferences_changed') return Object.keys(p).sort().join(',') === 'revision,version' && p.version === 1 && Number.isSafeInteger(p.revision) && Number(p.revision) > 0
  if (kind !== 'notification.queued') return true
  return Object.keys(p).sort().join(',') === 'binding_ref,conversation_id,generation,kind,message_id,ref,version' && p.version === 1 &&
    Number.isSafeInteger(p.generation) && Number(p.generation) > 0 && Number(p.generation) <= 1e9 && ['DM', 'TEXT'].includes(String(p.kind)) &&
    [p.ref, p.binding_ref, p.conversation_id, p.message_id].every(v => typeof v === 'string' && uuid.test(v))
}
