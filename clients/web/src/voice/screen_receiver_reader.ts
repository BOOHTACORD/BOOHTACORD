import type { ScreenViewerCard, ScreenViewerTrack } from './screen_viewer_types'
import type { ScreenReceiverSnapshot } from './screen_receiver_diagnostics'
import { screenSenderStatsSampler } from './screen_stats_sampler'

type Reader = NonNullable<ScreenViewerCard['readReceiverStats']>

function selectedReceiverRttMs(report: RTCStatsReport): number | undefined {
  const selectedPairIds = new Set<string>()
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type === 'transport' && typeof row.selectedCandidatePairId === 'string') selectedPairIds.add(row.selectedCandidatePairId)
  })
  if (selectedPairIds.size !== 1) return undefined
  const selectedId = selectedPairIds.values().next().value as string
  const pairs: Record<string, unknown>[] = []
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type === 'candidate-pair' && row.id === selectedId && row.state === 'succeeded') pairs.push(row)
  })
  if (pairs.length !== 1) return undefined
  const seconds = pairs[0]?.currentRoundTripTime
  if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0 || seconds > 60) return undefined
  return Math.round(seconds * 1000)
}

export function receiverSnapshotFromReport(report: RTCStatsReport): ScreenReceiverSnapshot | undefined {
  let selected: Record<string, unknown> | undefined
  let matches = 0
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type === 'inbound-rtp' && (row.kind ?? row.mediaType) === 'video' && typeof row.framesDecoded === 'number' && Number.isFinite(row.framesDecoded)) { selected = row; matches += 1 }
  })
  if (!selected || matches !== 1) return undefined
  const row = selected
  const number = (key: string) => typeof row[key] === 'number' && Number.isFinite(row[key]) ? row[key] as number : undefined
  const rttMs = selectedReceiverRttMs(report)
  return { timestamp: number('timestamp') ?? NaN, streamId: typeof row.id === 'string' ? row.id : undefined, ssrc: number('ssrc'),
    bytesReceived: number('bytesReceived'), framesDecoded: number('framesDecoded') ?? NaN,
    framesDropped: number('framesDropped') ?? NaN, packetsReceived: number('packetsReceived'), packetsLost: number('packetsLost'),
    jitter: number('jitter'), totalDecodeTime: number('totalDecodeTime'), jitterBufferDelay: number('jitterBufferDelay'),
    jitterBufferEmittedCount: number('jitterBufferEmittedCount'), nackCount: number('nackCount'), pliCount: number('pliCount'),
    firCount: number('firCount'), freezeCount: number('freezeCount'), totalFreezesDuration: number('totalFreezesDuration'),
    rttMs }
}

export function createScreenReceiverReader(): (track: ScreenViewerTrack) => Reader {
  const readers = new WeakMap<ScreenViewerTrack, Reader>()
  return (track) => {
    let reader = readers.get(track)
    if (!reader) {
      reader = async () => track.receiver ? receiverSnapshotFromReport(await screenSenderStatsSampler.read(track.receiver)) : track.getReceiverStats!()
      readers.set(track, reader)
    }
    return reader
  }
}
