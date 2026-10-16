import { setTimeout as delay } from 'node:timers/promises'

// Prepare the disposable browser before entering credentials. A successful
// document load alone can precede Chromium's startup network-change events.
// Observe three seconds of actual renderer GET navigation to the owned health
// endpoint. No authentication/registration request is retried by this barrier.
export async function prepareOwnedLoopback(page, origin,
  clock = { now: () => Date.now(), wait: delay }) {
  if (origin !== 'https://localhost:4810') throw new Error('Owned loopback origin required')
  const health = origin+'/api/v1/health', deadline = clock.now()+15000
  let stableSince = null
  for (let probe = 0; probe < 60 && clock.now() < deadline; probe++) {
    try {
      const response = await page.goto(health, { waitUntil: 'domcontentloaded',
        timeout: Math.min(3000, deadline-clock.now()) })
      if (response?.status() !== 200 || response.url() !== health)
        throw new Error('Owned browser health readiness failed')
      stableSince ??= clock.now()
      if (clock.now()-stableSince >= 3000) return await navigateOwnedLoopback(page, origin)
    } catch (error) {
      if (!(error instanceof Error) || !error.message.includes('net::ERR_NETWORK_CHANGED')) throw error
      stableSince = null
    }
    await clock.wait(250)
  }
  throw new Error('Owned browser network did not settle')
}

// A runner can publish a network-change event while its disposable services
// start. Retry only the initial read, never authentication or another mutation.
export async function navigateOwnedLoopback(page, origin) {
  if (origin !== 'https://localhost:4810') throw new Error('Owned loopback origin required')
  for (let attempt = 0; attempt < 3; attempt++) {
    try { return await page.goto(origin) }
    catch (error) {
      if (!(error instanceof Error) ||
          !error.message.includes('net::ERR_NETWORK_CHANGED') || attempt === 2) throw error
      await delay(250)
    }
  }
}
