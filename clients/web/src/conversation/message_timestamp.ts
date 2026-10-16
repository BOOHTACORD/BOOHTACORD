// Both labels use the same local clock; assistive technology also gets the date and zone.
export function messageTimestamp(createdAt: string, timeZone?: string): { short: string; full: string } {
  const date = new Date(createdAt)
  return {
    short: date.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', timeZone }),
    full: date.toLocaleString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit', timeZoneName: 'short', timeZone }),
  }
}
