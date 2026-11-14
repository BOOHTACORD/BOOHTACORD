import { afterEach, describe, expect, it, vi } from 'vitest'

import { startVoiceActivityHeartbeat } from './voice_activity_heartbeat'

describe('voice activity heartbeat', () => {
  afterEach(() => vi.useRealTimers())

  it('reports activity periodically only while the local participant is speaking', () => {
    vi.useFakeTimers()
    let speaking = false
    const reportActivity = vi.fn()
    const stop = startVoiceActivityHeartbeat(() => speaking, reportActivity)

    vi.advanceTimersByTime(20_000)
    expect(reportActivity).not.toHaveBeenCalled()

    speaking = true
    vi.advanceTimersByTime(30_000)
    expect(reportActivity).toHaveBeenCalledTimes(6)

    speaking = false
    vi.advanceTimersByTime(20_000)
    expect(reportActivity).toHaveBeenCalledTimes(6)

    stop()
    vi.advanceTimersByTime(20_000)
    expect(reportActivity).toHaveBeenCalledTimes(6)
  })
})
