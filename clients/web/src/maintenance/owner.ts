import { createGuestMaintenanceSocket } from './guest_socket'
import { createMaintenanceState } from './state'

type State = ReturnType<typeof createMaintenanceState>
type Guest = { start(): void; stop(): void }

export function createMaintenanceOwner(createGuest: (state: State) => Guest = state => createGuestMaintenanceSocket(state)) {
  const state = createMaintenanceState()
  let running = false, authenticated = false, guestRunning = false
  let guest: Guest | null = null
  function reconcile(): void {
    if (running && !authenticated) {
      if (!guestRunning) { guest ??= createGuest(state); guest.start(); guestRunning = true }
    } else if (guestRunning) {
      guest?.stop(); guestRunning = false
    }
  }
  return {
    state,
    start(): void { running = true; reconcile() },
    setAuthenticated(value: boolean): void { authenticated = value; reconcile() },
    stop(): void { running = false; reconcile() },
  }
}
