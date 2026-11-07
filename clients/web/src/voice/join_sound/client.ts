import { apiBaseUrl } from '../../config/runtime'

export type JoinSound = { id: string; revision: number; enabled: boolean }
type Request = (url: string, init: RequestInit) => Promise<Response>
export class JoinSoundClient {
  constructor(private readonly account: string, private readonly request: Request = (url, init) => fetch(url, init)) {}
  current(signal?: AbortSignal) { return this.send('GET', undefined, signal) }
  upload(file: Blob, signal?: AbortSignal) {
    if (!file.size || file.size > 2 * 1024 * 1024) return Promise.reject(new Error('Файл должен быть не больше 2 МиБ.'))
    return this.send('POST', file, signal)
  }
  enable(enabled: boolean, signal?: AbortSignal) { return this.send('PATCH', JSON.stringify({ enabled }), signal) }
  remove(signal?: AbortSignal) { return this.send('DELETE', undefined, signal) }
  private async send(method: string, body?: Blob | string, signal?: AbortSignal): Promise<JoinSound | null> {
    const response = await this.request(`${apiBaseUrl}/me/join-sound`, { method, body, signal, credentials: 'same-origin', redirect: 'error', cache: 'no-store', headers: { 'X-Voice-Sound-Account': this.account, ...(body ? { 'content-type': typeof body === 'string' ? 'application/json' : 'application/octet-stream' } : {}) } })
    if ((method === 'GET' && response.status === 404) || response.status === 204) return null
    if (!response.ok) throw new Error(response.status === 429 ? 'Повторите загрузку через 10 секунд.' : response.status === 400 ? 'Нужен MP3, WAV или OGG длительностью 0,3–3 секунды.' : 'Не удалось сохранить мелодию. Повторите попытку.')
    const value = await response.json()
    if (typeof value.id !== 'string' || !Number.isSafeInteger(value.revision) || typeof value.enabled !== 'boolean') throw new Error('Некорректный ответ сервера.')
    return value
  }
}
