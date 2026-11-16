import { describe, expect, it } from 'vitest'

import { compareScreenReceiverStats } from './screen_receiver_diagnostics'

describe('selected screen receiver diagnostics', () => {
  it('uses receiver counter deltas and timestamps for decoded FPS and bitrate', () => {
    const before = { timestamp: 1000, framesDecoded: 20, framesDropped: 1, bytesReceived: 100_000, packetsLost: 2 }
    const after = { timestamp: 3000, framesDecoded: 140, framesDropped: 4, bytesReceived: 1_100_000, packetsLost: 3, jitter: 0.012 }

    expect(compareScreenReceiverStats(before, after)).toMatchObject({
      bitrateKbps: 4000, decodedFrames: 140, decodedFps: 60, droppedFrames: 3, jitterMs: 12, packetsLost: 3, packetLossPercent: null,
    })
  })

  it('does not report a rate until a valid second sample is available', () => {
    const current = { timestamp: 2000, framesDecoded: 150, framesDropped: 5, bytesReceived: 900, packetsLost: 0 }
    expect(compareScreenReceiverStats(null, current)).toMatchObject({
      bitrateKbps: null, decodedFrames: 150, decodedFps: null, droppedFrames: null, jitterMs: null, packetsLost: 0, packetLossPercent: null,
    })
    expect(compareScreenReceiverStats({ ...current, timestamp: 3000 }, current).decodedFps).toBeNull()
    expect(compareScreenReceiverStats({ ...current, framesDecoded: 200 }, current).decodedFps).toBeNull()
    expect(compareScreenReceiverStats({ ...current, timestamp: 1000 }, { ...current, framesDecoded: Number.NaN }).decodedFps).toBeNull()
  })
})


it('does not bridge stream changes or stale windows into receiver rates', () => {
  const row = { timestamp: 1000, streamId: 'one', ssrc: 1, framesDecoded: 10, framesDropped: 1, bytesReceived: 100 }
  expect(compareScreenReceiverStats(row, { ...row, streamId: 'two', timestamp: 2000, framesDecoded: 40 }).decodedFps).toBeNull()
  expect(compareScreenReceiverStats(row, { ...row, timestamp: 20000, framesDecoded: 40 }).decodedFps).toBeNull()
})

it('calculates actual duration per decoded/emitted frame and cumulative SDK freezes', () => {
  const before = { timestamp: 1000, framesDecoded: 10, framesDropped: 1, totalDecodeTime: 0.1, jitterBufferDelay: 1, jitterBufferEmittedCount: 10 }
  const next = { ...before, timestamp: 2000, framesDecoded: 30, totalDecodeTime: 0.14, jitterBufferDelay: 1.1, jitterBufferEmittedCount: 30, freezeCount: 2, totalFreezesDuration: 0.5 }
  expect(compareScreenReceiverStats(before, next).decodeMsPerFrame).toBeCloseTo(2)
  expect(compareScreenReceiverStats(before, next)).toMatchObject({ freezeCount: 2, freezeDurationMs: 500, statsWindowMs: 1000 })
  expect(compareScreenReceiverStats(before, next).jitterBufferMsPerFrame).toBeCloseTo(5)
})

it('preserves only bounded receiver RTT as an instantaneous WebRTC measurement', () => {
  const current = { timestamp: 2000, framesDecoded: 30, framesDropped: 0, rttMs: 42 }
  expect(compareScreenReceiverStats(null, current).rttMs).toBe(42)
  expect(compareScreenReceiverStats(null, { ...current, rttMs: -1 }).rttMs).toBeNull()
  expect(compareScreenReceiverStats(null, { ...current, rttMs: 60_001 }).rttMs).toBeNull()
})
