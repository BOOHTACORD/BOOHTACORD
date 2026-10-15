// Never retain metric payloads, routes or resource/account labels in QA output.
export function rosterCounters(text) {
  const result = { closed: {}, failures: {} }
  const number = '([0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)'
  const closed = new RegExp('^voice_platform_voice_roster_stream_ends_total\\{reason="(canceled|session_expired|session_store|snapshot|write|other)"\\} '+number+'$')
  const failures = new RegExp('^voice_platform_voice_roster_failures_total\\{stage="(stream_snapshot|stream_write|stream_session_store|presence_room_list|presence_participants|presence_snapshot|visibility_initial|visibility_recheck)"\\} '+number+'$')
  const active = new RegExp('^voice_platform_voice_roster_streams_active '+number+'$')
  for (const line of text.split(/\r?\n/)) {
    let match = closed.exec(line)
    if (match && Number.isFinite(Number(match[2]))) result.closed[match[1]] = Number(match[2])
    match = failures.exec(line)
    if (match && Number.isFinite(Number(match[2]))) result.failures[match[1]] = Number(match[2])
    match = active.exec(line)
    if (match && Number.isFinite(Number(match[1]))) result.active = Number(match[1])
  }
  return result
}
