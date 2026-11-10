import { expect, it, vi } from 'vitest'
import { createAuthenticatedMaintenance } from './auth_owner'
import { createMaintenanceOwner } from './owner'

const payload = (active: boolean) => ({ version: 1, generation: '11111111-1111-4111-8111-111111111111', revision: 1, active })

it('hands maintenance ownership from guest to auth and back without late callbacks', () => {
  let guestToken = 0
  const guest = { start: vi.fn(), stop: vi.fn() }
  const owner = createMaintenanceOwner(state => {
    guest.start.mockImplementation(() => { guestToken = state.begin() })
    guest.stop.mockImplementation(() => state.disconnected(guestToken))
    return guest
  })
  owner.start()
  expect(guest.start).toHaveBeenCalledOnce()
  owner.state.accept(guestToken, { kind: 'maintenance.snapshot', payload: payload(true) })
  owner.setAuthenticated(true)
  expect(guest.stop).toHaveBeenCalledOnce()
  const auth = createAuthenticatedMaintenance(owner.state)
  auth.start()
  expect(owner.state.accept(guestToken, { kind: 'maintenance.changed', payload: { ...payload(false), revision: 2 } })).toBe(false)
  auth.accept({ kind: 'maintenance.snapshot', payload: payload(true) })
  owner.setAuthenticated(false)
  expect(guest.start).toHaveBeenCalledTimes(2)
  owner.state.accept(guestToken, { kind: 'maintenance.snapshot', payload: payload(true) })
  auth.stop()
  expect(owner.state.known.value).toBe(true)
  expect(owner.state.active.value).toBe(true)
  owner.stop()
  expect(owner.state.known.value).toBe(false)
})

it('does not open the guest socket while already authenticated', () => {
  const guest = { start: vi.fn(), stop: vi.fn() }
  const owner = createMaintenanceOwner(() => guest)
  owner.setAuthenticated(true)
  owner.start()
  expect(guest.start).not.toHaveBeenCalled()
  owner.setAuthenticated(false)
  expect(guest.start).toHaveBeenCalledOnce()
  owner.stop()
})
