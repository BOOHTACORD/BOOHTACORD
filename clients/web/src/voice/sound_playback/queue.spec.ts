import { afterEach, expect, it, vi } from 'vitest'
import { SoundPlaybackQueue } from './queue'

afterEach(() => { vi.useRealTimers() })
it('falls back exactly once when a custom sound arrives too late', async () => {
  vi.useFakeTimers()
  let finish!: (data: Uint8Array) => void
  const load = vi.fn(() => new Promise<Uint8Array>(resolve => { finish = resolve }))
  const play = vi.fn(async (_type: string, _bytes: Uint8Array | null, _signal: AbortSignal) => {})
  const queue = new SoundPlaybackQueue({ load, play }, () => true, 200)
  queue.submit({ type: 'joined', customId: 'safe-id' })
  await vi.advanceTimersByTimeAsync(201)
  finish(new Uint8Array([1])); await vi.runAllTimersAsync()
  expect(play).toHaveBeenCalledTimes(1)
  expect(play.mock.calls[0][1]).toBeNull()
})

it('suppresses a pending sound after leaving the room or disabling audio', async () => {
  let enabled = true
  let finish!: (data: Uint8Array) => void
  const play = vi.fn(async () => {})
  const queue = new SoundPlaybackQueue({ load: () => new Promise(resolve => { finish = resolve }), play }, () => enabled, 1000)
  queue.submit({ type: 'joined', customId: 'safe-id' })
  enabled = false; queue.clear()
  finish(new Uint8Array([1])); await Promise.resolve(); await Promise.resolve()
  expect(play).not.toHaveBeenCalled()
})

it('serializes playback and bounds the backlog to one waiting sound', async () => {
  let finish!: () => void
  const play = vi.fn().mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve })).mockResolvedValue(undefined)
  const queue = new SoundPlaybackQueue({ load: vi.fn(), play }, () => true, 200)
  queue.submit({ type: 'joined' }); queue.submit({ type: 'left' }); queue.submit({ type: 'started' })
  expect(play).toHaveBeenCalledTimes(1)
  finish(); await vi.waitFor(() => expect(play).toHaveBeenCalledTimes(2))
  expect(play.mock.calls.map(call => call[0])).toEqual(['joined', 'left'])
})

it('uses default once if a custom file cannot be decoded', async () => {
  const play = vi.fn().mockRejectedValueOnce(new Error('decode')).mockResolvedValue(undefined)
  const queue = new SoundPlaybackQueue({ load: vi.fn(async () => new Uint8Array([1])), play }, () => true, 200)
  queue.submit({ type: 'joined', customId: 'safe-id' })
  await vi.waitFor(() => expect(play).toHaveBeenCalledTimes(2))
  expect(play.mock.calls[0][1]).toEqual(new Uint8Array([1]))
  expect(play.mock.calls[1][1]).toBeNull()
})

it('limits bursts to three sounds in five seconds even after clearing', async () => {
  vi.useFakeTimers()
  const play = vi.fn(async () => {})
  const queue = new SoundPlaybackQueue({ load: vi.fn(), play }, () => true, 200)
  for (let i = 0; i < 4; i++) { queue.submit({ type: 'joined' }); await vi.advanceTimersByTimeAsync(1) }
  queue.clear(); queue.submit({ type: 'left' }); await vi.advanceTimersByTimeAsync(1)
  expect(play).toHaveBeenCalledTimes(3)
  await vi.advanceTimersByTimeAsync(5000); queue.submit({ type: 'left' }); await vi.advanceTimersByTimeAsync(1)
  expect(play).toHaveBeenCalledTimes(4)
})
