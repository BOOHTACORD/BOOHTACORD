// A UI can enter its pending state before Playwright dispatches the request to
// its route handler. Pair each test-side release with one actual held request.
export function createResponseGate() {
  const requests: Array<() => void> = []
  const releases: Array<(unlock: () => void) => void> = []
  return {
    hold(): Promise<void> {
      return new Promise(unlock => {
        const waiting = releases.shift()
        if (waiting) waiting(unlock)
        else requests.push(unlock)
      })
    },
    async releaseNext(): Promise<void> {
      const unlock = requests.shift() ?? await new Promise<() => void>(resolve => releases.push(resolve))
      unlock()
    },
  }
}
