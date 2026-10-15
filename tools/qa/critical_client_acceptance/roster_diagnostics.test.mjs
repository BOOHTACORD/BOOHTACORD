import { test } from 'node:test'
import assert from 'node:assert/strict'
import { rosterCounters } from './roster_diagnostics.mjs'

test('retains only finite counters with fixed roster failure labels', () => {
  assert.deepEqual(rosterCounters(`
voice_platform_voice_roster_stream_ends_total{reason="snapshot"} 2
voice_platform_voice_roster_stream_ends_total{reason="canceled"} 3
voice_platform_voice_roster_failures_total{stage="stream_write"} 4
voice_platform_voice_roster_streams_active 1
`), { closed: { snapshot: 2, canceled: 3 }, failures: { stream_write: 4 }, active: 1 })
})

test('drops identities, unexpected labels, foreign metrics and invalid values', () => {
  const actual = rosterCounters(`
voice_platform_voice_roster_stream_ends_total{reason="private identity"} 1
voice_platform_voice_roster_stream_ends_total{reason="snapshot",account="private identity"} 1
voice_platform_voice_roster_failures_total{stage="private message"} 1
voice_platform_voice_roster_stream_ends_total{reason="write"} +Inf
voice_platform_voice_roster_stream_ends_total{reason="other"} -1
foreign_metric{body="private message"} 1
`)
  assert.deepEqual(actual, { closed: {}, failures: {} })
  assert.ok(!JSON.stringify(actual).includes('private'))
})
