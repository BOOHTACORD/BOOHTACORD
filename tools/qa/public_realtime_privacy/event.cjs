function keys(value, expected) {
  return value && typeof value === 'object' && !Array.isArray(value) &&
    Object.keys(value).sort().join(',') === [...expected].sort().join(',')
}

function allowed(event) {
  if (!keys(event, ['event_id', 'occurred_at', 'kind', 'payload']) ||
      typeof event.event_id !== 'string' || typeof event.occurred_at !== 'string') return false
  if (event.kind === 'connection.ready') return keys(event.payload, [])
  if (!['maintenance.snapshot', 'maintenance.changed'].includes(event.kind) ||
      !keys(event.payload, ['version', 'generation', 'revision', 'active'])) return false
  const data = event.payload
  return data.version === 1 && typeof data.generation === 'string' &&
    Number.isSafeInteger(data.revision) && data.revision > 0 && typeof data.active === 'boolean'
}

module.exports = { allowed }
