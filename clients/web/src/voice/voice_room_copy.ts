function plural(value: number, forms: [string, string, string]): string {
  const lastTwo = value % 100
  if (lastTwo >= 11 && lastTwo <= 14) return forms[2]
  const last = value % 10
  if (last === 1) return forms[0]
  return last >= 2 && last <= 4 ? forms[1] : forms[2]
}

function count(value: number): number {
  return Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0
}

export function voiceRoomSummary(participants: number, screens: number): string {
  const people = count(participants)
  const shares = count(screens)
  if (shares === 0) return `${people} ${plural(people, ['участник', 'участника', 'участников'])}`
  return `${people} ${plural(people, ['участник', 'участника', 'участников'])} · ${shares} ${plural(shares, ['демонстрация экрана', 'демонстрации экрана', 'демонстраций экрана'])}`
}
