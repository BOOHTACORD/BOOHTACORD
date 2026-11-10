import { api } from '../client_lifecycle/request.mjs'
import { rosterCounters } from './roster_diagnostics.mjs'

export async function diagnoseRosterFailure(page, network, directory) {
  const transport = await page.evaluate(() => ({
    ...window.__qaRosterTransport,
    ready_state: window.__qaRosterTransportSource?.readyState ?? null,
    unavailable: window.__qaRosterUnavailableCount,
  }))
  const presenceStatus = (await api(page, '/voice/participants')).status
  console.error('roster-failure-diagnostics='+JSON.stringify({ ...transport, presence_status: presenceStatus,
    network: network(), workspace_present: await page.getByTestId('app-shell').count() > 0 }))
  try { await page.screenshot({ path: directory+'/roster-event-failure.png' }) } catch { /* Keep the event failure. */ }
  try {
    const response = await fetch('http://127.0.0.1:4820/metrics', { signal: AbortSignal.timeout(2000) })
    if (response.ok) console.error('roster-server-counters='+JSON.stringify(rosterCounters(await response.text())))
  } catch { /* Keep the event failure. */ }
}
