import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { VoiceSoundPolicy, type VoiceSoundEvent } from './policy'

type Fixture = { name: string; members: { actor: string; lease: string }[]; streams: { actor: string; session: string }[]; steps: (Omit<VoiceSoundEvent, 'channel'> | { flush: number })[]; expected: string[] }
const cases = JSON.parse(readFileSync(new URL('../../../../../contracts/voice-sound-event-policy.fixtures.json', import.meta.url), 'utf8')) as Fixture[]
describe('shared voice sound policy fixtures', () => {
  for (const fixture of cases) it(fixture.name, () => {
    const played: string[] = [], policy = new VoiceSoundPolicy('room', 'self', e => played.push(e.type))
    policy.seed(fixture.members, fixture.streams)
    for (const step of fixture.steps) {
      if ('flush' in step) policy.flush(step.flush)
      else policy.accept({ ...step, channel: 'room' }, step.time)
    }
    expect(played).toEqual(fixture.expected)
  })
})
