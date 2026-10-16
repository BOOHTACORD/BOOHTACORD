import { setTimeout as delay } from 'node:timers/promises'

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
