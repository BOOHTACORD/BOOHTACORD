export function createActivityThrottle(now: () => number = () => performance.now()) {
  let last: number | null = null
  return {
    ready: () => last === null || now() < last || now() - last >= 10_000,
    sent: () => { last = now() },
  }
}
