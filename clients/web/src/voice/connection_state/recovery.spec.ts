import { afterEach, describe, expect, it, vi } from 'vitest'
import { VoiceRecoveryLoop, type VoiceRecoveryTarget } from './recovery'

const target: VoiceRecoveryTarget = { channelId: 'voice-42', leaseId: 'lease-old', joinMode: 'listener', deafened: true }

afterEach(() => { vi.useRealTimers() })

describe('long-lived voice recovery supervisor', () => {
  it('keeps retrying beyond SDK attempts in the original channel and mode', async () => {
    vi.useFakeTimers()
    const attempt = vi.fn().mockResolvedValueOnce('retry').mockResolvedValueOnce('retry').mockResolvedValue('restored')
    const loop = new VoiceRecoveryLoop(attempt, vi.fn(), () => 0)
    loop.start(target)
    await vi.advanceTimersByTimeAsync(1000)
    await vi.advanceTimersByTimeAsync(800)
    await vi.advanceTimersByTimeAsync(1600)
    expect(attempt).toHaveBeenCalledTimes(3)
    expect(attempt.mock.calls.every(([value]: [VoiceRecoveryTarget]) => value === target)).toBe(true)
    expect(loop.active).toBe(false)
  })

  it('cancels delayed and in-flight callbacks after Leave', async () => {
    vi.useFakeTimers()
    let settle!: (value: 'retry') => void
    const attempt = vi.fn(() => new Promise<'retry'>(resolve => { settle = resolve }))
    const loop = new VoiceRecoveryLoop(attempt, vi.fn())
    loop.start(target)
    await vi.advanceTimersByTimeAsync(1000)
    loop.cancel()
    settle('retry')
    await Promise.resolve()
    await vi.advanceTimersByTimeAsync(90000)
    expect(attempt).toHaveBeenCalledOnce()
    expect(loop.active).toBe(false)
  })

  it('stops on a terminal error without another attempt', async () => {
    vi.useFakeTimers()
    const attempt = vi.fn().mockResolvedValue('stop')
    const loop = new VoiceRecoveryLoop(attempt, vi.fn())
    loop.start(target)
    await vi.advanceTimersByTimeAsync(1000)
    await vi.advanceTimersByTimeAsync(90000)
    expect(attempt).toHaveBeenCalledOnce()
    expect(loop.channelId).toBeNull()
  })
})
