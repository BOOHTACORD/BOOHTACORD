import { expect, it } from 'vitest'
import { receiverSnapshotFromReport } from './screen_receiver_reader'
const report = (rows: Record<string, unknown>[]) => new Map(rows.map((row, index) => [String(index), row])) as unknown as RTCStatsReport
it('reads actual primary video counters and ignores audio and RTX rows', () => {
  const snapshot = receiverSnapshotFromReport(report([
    { id: 'audio', type: 'inbound-rtp', kind: 'audio', framesDecoded: 9 },
    { id: 'video', type: 'inbound-rtp', kind: 'video', ssrc: 10, timestamp: 2000, framesDecoded: 30, totalDecodeTime: 0.06, freezeCount: 2 },
    { id: 'rtx', type: 'inbound-rtp', kind: 'video', bytesReceived: 20 },
  ]))
  expect(snapshot).toMatchObject({ streamId: 'video', ssrc: 10, framesDecoded: 30, totalDecodeTime: 0.06, freezeCount: 2 })
  expect(snapshot?.jitterBufferEmittedCount).toBeUndefined()
})
it('returns unavailable for ambiguous or unsupported video counters', () => {
  expect(receiverSnapshotFromReport(report([{ type: 'inbound-rtp', kind: 'video' }]))).toBeUndefined()
  expect(receiverSnapshotFromReport(report([{ type: 'inbound-rtp', kind: 'video', framesDecoded: 10 }, { type: 'inbound-rtp', kind: 'video', framesDecoded: 20 }]))).toBeUndefined()
})

it('reads RTT only from the uniquely selected successful WebRTC candidate pair', () => {
  const snapshot = receiverSnapshotFromReport(report([
    { id: 'video', type: 'inbound-rtp', kind: 'video', timestamp: 2000, framesDecoded: 30 },
    { id: 'transport', type: 'transport', selectedCandidatePairId: 'selected-pair' },
    { id: 'selected-pair', type: 'candidate-pair', state: 'succeeded', currentRoundTripTime: 0.042 },
    { id: 'other-pair', type: 'candidate-pair', state: 'succeeded', currentRoundTripTime: 0.8 },
  ]))
  expect(snapshot?.rttMs).toBe(42)
})

it('keeps RTT unavailable when the selected pair is missing, ambiguous, or outside bounds', () => {
  const video = { id: 'video', type: 'inbound-rtp', kind: 'video', timestamp: 2000, framesDecoded: 30 }
  const selected = { id: 'transport', type: 'transport', selectedCandidatePairId: 'pair' }
  const validPair = { id: 'pair', type: 'candidate-pair', state: 'succeeded', currentRoundTripTime: 0 }
  expect(receiverSnapshotFromReport(report([video]))?.rttMs).toBeUndefined()
  expect(receiverSnapshotFromReport(report([video, selected, { ...validPair, currentRoundTripTime: 61 }]))?.rttMs).toBeUndefined()
  expect(receiverSnapshotFromReport(report([video, selected, { ...validPair, state: 'in-progress' }]))?.rttMs).toBeUndefined()
  expect(receiverSnapshotFromReport(report([video, selected, validPair, { ...validPair, currentRoundTripTime: 0.2 }]))?.rttMs).toBeUndefined()
  expect(receiverSnapshotFromReport(report([video, selected, { id: 'transport-2', type: 'transport', selectedCandidatePairId: 'other' }, validPair, { ...validPair, id: 'other' }]))?.rttMs).toBeUndefined()
  expect(receiverSnapshotFromReport(report([video, selected, validPair, { ...validPair, id: 'other' }]))?.rttMs).toBe(0)
})
