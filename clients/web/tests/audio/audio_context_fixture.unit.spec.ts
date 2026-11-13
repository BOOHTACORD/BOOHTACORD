import { describe, expect, it, vi } from 'vitest'
import { resumeAudio } from './audio_context_fixture'

describe('audio context readiness', () => {
  it('cleans up and reports a blocked audio context', async () => {
    vi.useFakeTimers()
    const close = vi.fn().mockResolvedValue(undefined)
    const context = { state: 'suspended', resume: () => new Promise(() => {}), close } as unknown as AudioContext
    const result = expect(resumeAudio(context)).rejects.toThrow('AudioContext resume timed out; state=suspended')
    await vi.advanceTimersByTimeAsync(8000)
    await result
    expect(close).toHaveBeenCalledOnce()
    vi.useRealTimers()
  })
})
