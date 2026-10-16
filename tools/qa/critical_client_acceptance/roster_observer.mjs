// Observe transport control events only; never retain roster payloads or identities.
export function installRosterFailureObserver(browser = window) {
  const Native = browser.EventSource
  browser.__qaRosterUnavailableCount = 0
  browser.__qaRosterTransport = { created: 0, opened: 0, failed: 0, closed_by_client: 0, latest_closed_by_client: false }
  browser.__qaRosterTransportSource = null
  browser.EventSource = new Proxy(Native, { construct(target, args, newTarget) {
    const source = Reflect.construct(target, args, newTarget)
    if (new URL(args[0], browser.location.href).pathname === '/api/v1/voice/rosters/events') {
      browser.__qaRosterTransport.created++
      browser.__qaRosterTransport.latest_closed_by_client = false
      browser.__qaRosterTransportSource = source
      const close = source.close
      source.close = function (...args) {
        browser.__qaRosterTransport.closed_by_client++
        if (browser.__qaRosterTransportSource === source) browser.__qaRosterTransport.latest_closed_by_client = true
        return Reflect.apply(close, this, args)
      }
      source.addEventListener('open', () => { browser.__qaRosterTransport.opened++ })
      source.addEventListener('error', () => { browser.__qaRosterTransport.failed++ })
      source.addEventListener('roster-unavailable', () => { browser.__qaRosterUnavailableCount++ })
    }
    return source
  } })
}
