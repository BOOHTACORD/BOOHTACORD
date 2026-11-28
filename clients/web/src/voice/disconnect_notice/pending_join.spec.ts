import { ref, shallowRef } from 'vue'
import { expect, it } from 'vitest'
import { createVoiceConnectionRevocation } from './revocation'
import type { RevocationContext } from './revocation_context'
import { createVoiceDisconnectState } from './state'

function setup() {
  const terminal = createVoiceDisconnectState(() => {})
  terminal.bind('current-lease', 'voice')
  const revocation = createVoiceConnectionRevocation({ terminal, state: ref('JOINING'), active: shallowRef(null) } as unknown as RevocationContext)
  return { terminal, revocation }
}

it('does not cancel the current admission for an obsolete lease event', async () => {
  const { revocation } = setup()
  await revocation.revokeLease('old-lease', 'VOLUNTARY_LEAVE')
  expect(revocation.joinCancelled('current-lease')).toBe(false)
})

it('cancels a pending retry when the server revokes its exact lease', async () => {
  const { terminal, revocation } = setup()
  await revocation.revokeLease('current-lease', 'VOLUNTARY_LEAVE')
  expect(revocation.joinCancelled('current-lease')).toBe(true)
  terminal.reset(); revocation.resetPending(); terminal.bind('successor-lease', 'voice')
  expect(revocation.joinCancelled('successor-lease')).toBe(false)
})

it('cancels a pending retry for local logout or teardown before a room exists', async () => {
  const { revocation } = setup()
  await revocation.disconnectLocal('VOLUNTARY_LEAVE')
  expect(revocation.joinCancelled('current-lease')).toBe(true)
})
