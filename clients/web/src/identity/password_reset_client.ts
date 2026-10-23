import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { capacityError, rateLimitError } from './authentication_flow/retry_after'

export type PasswordResetRequest = (input: string, init: RequestInit) => Promise<Response>

export class PasswordResetInvalidError extends Error {
  constructor() { super('Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.') }
}

export async function completePasswordReset(token: string, password: string, request: PasswordResetRequest = tracedFetch): Promise<void> {
  let response: Response
  try {
    response = await request(`${apiBaseUrl}/auth/password-reset/complete`, {
      method: 'POST', credentials: 'same-origin', cache: 'no-store', referrerPolicy: 'no-referrer',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ token, password }),
    })
  } catch {
    throw new Error('Нет связи с сервером. Повторите попытку.')
  }
  if (response.status === 204) return
  if (response.status === 400) throw new PasswordResetInvalidError()
  if (response.status === 429) throw rateLimitError(response)
  const busy = await capacityError(response)
  if (busy) throw busy
  throw new Error(`Не удалось изменить пароль (${response.status}). Повторите попытку.`)
}
