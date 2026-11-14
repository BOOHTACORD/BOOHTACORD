import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'

export type VoiceDeafenRequest = (input: string, init: RequestInit) => Promise<Response>

export async function publishVoiceDeafened(leaseId: string, deafened: boolean, request: VoiceDeafenRequest = tracedFetch): Promise<void> {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(leaseId)) throw new Error('Не удалось обновить состояние отключения звука.')
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(leaseId)}/deafen/v1`, {
    method: 'PUT', credentials: 'same-origin', cache: 'no-store',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ deafened }),
  })
  if (!response.ok) throw new Error('Не удалось обновить состояние отключения звука.')
}
