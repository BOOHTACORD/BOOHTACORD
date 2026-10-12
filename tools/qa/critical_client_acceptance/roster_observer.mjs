// Observe transport control events only; never retain roster payloads or identities.
export function installRosterFailureObserver(browser = window) {
  const Native = browser.EventSource
  browser.__qaRosterUnavailableCount = 0
  browser.EventSource = new Proxy(Native, { construct(target, args, newTarget) {
    const source = Reflect.construct(target, args, newTarget)
    if (new URL(args[0], browser.location.href).pathname === '/api/v1/voice/rosters/events') {
      source.addEventListener('roster-unavailable', () => { browser.__qaRosterUnavailableCount++ })
    }
    return source
  } })
}
