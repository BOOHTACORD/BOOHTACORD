import { afterEach, describe, expect, it, vi } from 'vitest'
import { createRenderer, nextTick, ref } from 'vue'

import type { ScreenViewerCard } from './screen_viewer_types'
import { useScreenReceiverDiagnostics } from './use_screen_receiver_diagnostics'

const renderer = createRenderer<any, any>({
  createComment: () => ({}), createElement: () => ({}), createText: () => ({}),
  insert: () => {}, nextSibling: () => null, parentNode: () => null,
  patchProp: () => {}, remove: () => {}, setElementText: () => {}, setText: () => {},
})

afterEach(() => vi.useRealTimers())

describe('receiver sampling lifecycle', () => {
  it('feeds ten-second packet deltas into the visible metrics', async () => {
    vi.useFakeTimers()
    let count = 0
    const readReceiverStats = vi.fn().mockImplementation(async () => {
      const index = count++
      return {
        timestamp: index * 1000, framesDecoded: index * 60, framesDropped: 0,
        packetsReceived: 1000 + index * 99.5, packetsLost: 2476 + (index > 0 ? 5 : 0),
      }
    })
    const selected = ref<ScreenViewerCard | null>({ id: 'screen', hasAudio: false, participantId: 'a', participantName: 'A', readReceiverStats })
    let observed: ReturnType<typeof useScreenReceiverDiagnostics> | undefined
    const app = renderer.createApp({ setup() { observed = useScreenReceiverDiagnostics(selected, () => false); return () => null } })
    app.mount({})
    await vi.advanceTimersByTimeAsync(8000)
    expect(observed?.metrics.value?.packetLossPercent).toBeNull()
    await vi.advanceTimersByTimeAsync(2000)
    expect(observed?.metrics.value?.packetLossPercent).toBe(0.5)
    app.unmount()
  })

  it('measures consecutive receiver samples and resets when the viewed screen changes', async () => {
    vi.useFakeTimers()
    const first = vi.fn()
      .mockResolvedValueOnce({ timestamp: 1000, framesDecoded: 20, framesDropped: 0, bytesReceived: 1000 })
      .mockResolvedValueOnce({ timestamp: 3000, framesDecoded: 140, framesDropped: 1, bytesReceived: 1_001_000 })
    const selected = ref<ScreenViewerCard | null>({ id: 'first', hasAudio: false, participantId: 'a', participantName: 'A', readReceiverStats: first })
    let observed: ReturnType<typeof useScreenReceiverDiagnostics> | undefined
    const app = renderer.createApp({ setup() { observed = useScreenReceiverDiagnostics(selected, () => false); return () => null } })
    app.mount({})
    await Promise.resolve()
    expect(observed?.metrics.value?.decodedFps).toBeNull()

    await vi.advanceTimersByTimeAsync(1000)
    expect(observed?.metrics.value?.decodedFps).toBe(60)
    expect(observed?.metrics.value?.bitrateKbps).toBe(4000)

    const second = vi.fn().mockResolvedValue({ timestamp: 5000, framesDecoded: 10, framesDropped: 0 })
    selected.value = { ...selected.value!, id: 'second', readReceiverStats: second }
    await nextTick()
    await Promise.resolve()
    expect(observed?.metrics.value?.decodedFps).toBeNull()
    expect(second).toHaveBeenCalledOnce()

    app.unmount()
    await vi.advanceTimersByTimeAsync(4000)
    expect(second).toHaveBeenCalledOnce()
  })

  it('keeps the last successful sample through intermittent unavailable and failed reads', async () => {
    vi.useFakeTimers()
    const readReceiverStats = vi.fn()
      .mockResolvedValueOnce({ timestamp: 1000, framesDecoded: 20, framesDropped: 0, bytesReceived: 1000 })
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(new Error('temporary stats read failure'))
      .mockResolvedValueOnce({ timestamp: 4000, framesDecoded: 200, framesDropped: 1, bytesReceived: 1_501_000 })
    const selected = ref<ScreenViewerCard | null>({ id: 'screen', hasAudio: true, participantId: 'a', participantName: 'A', readReceiverStats })
    let observed: ReturnType<typeof useScreenReceiverDiagnostics> | undefined
    const app = renderer.createApp({ setup() { observed = useScreenReceiverDiagnostics(selected, () => false); return () => null } })
    app.mount({})
    await Promise.resolve()
    const firstMetrics = observed?.metrics.value
    expect(observed?.sampledAt.value).toBe(1000)

    await vi.advanceTimersByTimeAsync(1000)
    expect(observed?.sampledAt.value).toBe(1000)
    expect(observed?.metrics.value).toBe(firstMetrics)

    await vi.advanceTimersByTimeAsync(1000)
    expect(observed?.sampledAt.value).toBe(1000)
    expect(observed?.metrics.value).toBe(firstMetrics)

    await vi.advanceTimersByTimeAsync(1000)
    expect(observed?.sampledAt.value).toBe(4000)
    expect(observed?.metrics.value?.decodedFps).toBe(60)
    expect(observed?.metrics.value?.bitrateKbps).toBe(4000)
    app.unmount()
  })
})
