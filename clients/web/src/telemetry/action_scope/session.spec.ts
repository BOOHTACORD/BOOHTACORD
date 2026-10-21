import { describe, expect, it } from 'vitest'

import { TelemetrySession } from './session'

describe('media session binding', () => {
  it('invalidates queued ownership when the installation changes at the same origin', () => {
    const session = new TelemetrySession()
    session.bindInstallation('11111111-1111-4111-8111-111111111111')
    session.bind('a'.repeat(32), '1')
    const previous = session.snapshot()
    session.bindInstallation('22222222-2222-4222-8222-222222222222')
    expect(session.current(previous)).toBe(false)
    expect(session.snapshot().binding).toBeNull()
    expect(session.snapshot().installation).toBe('22222222-2222-4222-8222-222222222222')
  })
  it('uses the server-issued voice lease handle as the stable media-session id', () => {
    const session = new TelemetrySession()
    session.bind('a'.repeat(32), '1')
    session.beginMedia()
    session.bindMediaFlow('b'.repeat(32))

    expect(session.bindMediaLease('11111111-1111-4111-8111-111111111111')).toBe(true)
    expect(session.snapshot()).toMatchObject({
      leaseId: '11111111-1111-4111-8111-111111111111',
      media: '11111111111141118111111111111111',
      mediaFlow: 'b'.repeat(32),
    })
  })

  it('rejects malformed lease handles and clears media ownership on leave/reset', () => {
    const session = new TelemetrySession()
    session.beginMedia()
    expect(session.bindMediaLease('not-a-lease')).toBe(false)
    expect(session.snapshot().leaseId).toBeNull()
    session.bindMediaLease('11111111-1111-4111-8111-111111111111')
    session.endMedia()
    expect(session.snapshot()).toMatchObject({ leaseId: null, media: null, mediaFlow: null })
  })
})
