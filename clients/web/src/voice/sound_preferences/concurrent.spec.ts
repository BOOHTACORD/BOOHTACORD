import { expect, it, vi } from 'vitest'
import { VoiceSoundPreferences } from './state'

const settings = { enabled: true, joined: true, left: true, started: true, stopped: true, allow_custom: true, volume: 50 }
const reply = (revision: number, values = settings) => new Response(JSON.stringify({ revision, settings: values }), { status: 200 })

it('serializes rapid changes and persists the latest value of each field', async () => {
  let finish!: (value: Response) => void
  const request = vi.fn().mockResolvedValueOnce(reply(0))
    .mockImplementationOnce(() => new Promise<Response>(resolve => { finish = resolve }))
    .mockResolvedValueOnce(reply(2, { ...settings, joined: false, left: false }))
  const store = new VoiceSoundPreferences(request)
  await store.select('account-a')
  const first = store.patch({ joined: false })
  const second = store.patch({ left: false })
  expect(store.settings.value.left).toBe(false)
  await Promise.resolve()
  finish(reply(1, { ...settings, joined: false }))
  await Promise.all([first, second])
  expect(request).toHaveBeenCalledTimes(3)
  expect(JSON.parse(request.mock.calls[2][1].body)).toEqual({ expected_revision: 1, left: false })
  expect(store.settings.value.left).toBe(false)
  expect(store.unsynchronised.value).toBe(false)
})

it('reports an unsaved enabling change after a network failure', async () => {
  const request = vi.fn().mockResolvedValueOnce(reply(0, { ...settings, joined: false })).mockRejectedValueOnce(new Error('offline'))
  const store = new VoiceSoundPreferences(request)
  await store.select('account-a'); await store.patch({ joined: true })
  expect(store.settings.value.joined).toBe(false)
  expect(store.unsynchronised.value).toBe(true)
})

it('does not send a queued change after switching accounts', async () => {
  let finish!: (value: Response) => void
  const request = vi.fn().mockResolvedValueOnce(reply(0))
    .mockImplementationOnce(() => new Promise<Response>(resolve => { finish = resolve }))
    .mockResolvedValueOnce(reply(0))
  const store = new VoiceSoundPreferences(request)
  await store.select('account-a')
  const first = store.patch({ joined: false }); await Promise.resolve()
  const second = store.patch({ left: false }); await store.select('account-b')
  finish(reply(1, { ...settings, joined: false }))
  await Promise.all([first, second])
  expect(request).toHaveBeenCalledTimes(3)
  expect(store.settings.value).toEqual(settings)
})

it('keeps a newer OFF until its own acknowledgement arrives', async () => {
  let firstReply!: (value: Response) => void
  let secondReply!: (value: Response) => void
  const request = vi.fn().mockResolvedValueOnce(reply(0))
    .mockImplementationOnce(() => new Promise<Response>(resolve => { firstReply = resolve }))
    .mockImplementationOnce(() => new Promise<Response>(resolve => { secondReply = resolve }))
  const store = new VoiceSoundPreferences(request)
  await store.select('account-a')
  const first = store.patch({ joined: false }); await Promise.resolve()
  const second = store.patch({ joined: false })
  firstReply(reply(1, { ...settings, joined: false })); await first
  expect(store.settings.value.joined).toBe(false)
  expect(store.unsynchronised.value).toBe(true)
  await vi.waitFor(() => expect(secondReply).toBeDefined())
  secondReply(reply(2, { ...settings, joined: false })); await second
  expect(store.unsynchronised.value).toBe(false)
})
