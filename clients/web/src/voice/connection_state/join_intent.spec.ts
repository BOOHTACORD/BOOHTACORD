import { expect, it, vi } from 'vitest'
import { joinedSession, setup, type SessionJoin } from './join_fixture'

it('invalidates the room retry intent when leave resets the admission generation', async () => {
  let admittedCurrent!: () => boolean
  const sessionJoin = vi.fn<SessionJoin>(async (_channel, _transfer, _mode, current) => {
    admittedCurrent = current!
    return joinedSession
  })
  const state = setup(sessionJoin, vi.fn(async () => true))
  await state.join('voice-target', false, 'listener')
  expect(admittedCurrent()).toBe(true)
  state.terminal.reset()
  expect(admittedCurrent()).toBe(false)
})

it('propagates an exact lease revocation into the pending room retry intent', async () => {
  let admittedCurrent!: () => boolean
  const sessionJoin = vi.fn<SessionJoin>(async (_channel, _transfer, _mode, current) => {
    admittedCurrent = current!
    return joinedSession
  })
  const state = setup(sessionJoin, vi.fn(async () => true))
  await state.join('voice-target', false, 'listener')
  vi.mocked(state.revocation.joinCancelled).mockReturnValue(true)
  expect(admittedCurrent()).toBe(false)
  expect(state.revocation.joinCancelled).toHaveBeenCalledWith('lease-new')
})
