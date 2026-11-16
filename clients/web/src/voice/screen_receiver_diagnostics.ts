export interface ScreenReceiverSnapshot {
  streamId?: string
  ssrc?: number
  totalDecodeTime?: number
  jitterBufferDelay?: number
  jitterBufferEmittedCount?: number
  nackCount?: number
  pliCount?: number
  firCount?: number
  freezeCount?: number
  totalFreezesDuration?: number
  bytesReceived?: number
  framesDecoded: number
  framesDropped: number
  jitter?: number
  packetsLost?: number
  packetsReceived?: number
  rttMs?: number
  timestamp: number
}

export interface ScreenReceiverMetrics {
  statsWindowMs?: number | null
  collectionState?: 'active' | 'inactive' | 'unknown' | 'stale'
  decodeMsPerFrame?: number | null
  jitterBufferMsPerFrame?: number | null
  nackPerSecond?: number | null
  pliPerSecond?: number | null
  firPerSecond?: number | null
  freezeCount?: number | null
  freezeDurationMs?: number | null
  decodedFrames?:number|null
  packetLossWindowMs?: number | null
  bitrateKbps: number | null
  decodedFps: number | null
  droppedFrames: number | null
  jitterMs: number | null
  packetsLost: number | null
  packetLossPercent: number | null
  rttMs: number | null
}

function rate(previous: number | undefined, current: number | undefined, elapsedMs: number, multiplier: number): number | null {
  if (previous === undefined || current === undefined || !Number.isFinite(previous) || !Number.isFinite(current) || !Number.isFinite(elapsedMs) || elapsedMs <= 0 || current < previous) return null
  return Math.round(((current - previous) * multiplier / elapsedMs) * 10) / 10
}

export function compareScreenReceiverStats(previous: ScreenReceiverSnapshot | null, current: ScreenReceiverSnapshot): ScreenReceiverMetrics {
  const same = previous && previous.streamId === current.streamId && previous.ssrc === current.ssrc
  const elapsed = same ? current.timestamp - previous.timestamp : 0
  const reset = previous && [['framesDecoded'], ['bytesReceived'], ['packetsReceived']].some(([key]) => {
    const a = current[key as keyof ScreenReceiverSnapshot], b = previous[key as keyof ScreenReceiverSnapshot]
    return typeof a === 'number' && typeof b === 'number' && a < b
  })
  const elapsedMs = elapsed > 0 && elapsed <= 10000 && !reset ? elapsed : 0
  const delta = (a: number | undefined, b: number | undefined) => elapsedMs && a !== undefined && b !== undefined && Number.isFinite(a) && Number.isFinite(b) && a >= b && b >= 0 ? a - b : null
  const frames = delta(current.framesDecoded, previous?.framesDecoded)
  const decode = delta(current.totalDecodeTime, previous?.totalDecodeTime)
  const delay = delta(current.jitterBufferDelay, previous?.jitterBufferDelay)
  const emitted = delta(current.jitterBufferEmittedCount, previous?.jitterBufferEmittedCount)
  const dropped = previous && elapsedMs > 0 && Number.isFinite(current.framesDropped) && current.framesDropped >= previous.framesDropped ? current.framesDropped - previous.framesDropped : null
  return {
    statsWindowMs: elapsedMs || null,
    collectionState: elapsed > 10000 ? 'stale' : !elapsedMs || frames === null ? 'unknown' : frames === 0 ? 'inactive' : 'active',
    decodeMsPerFrame: frames && decode !== null ? decode * 1000 / frames : null,
    jitterBufferMsPerFrame: emitted && delay !== null ? delay * 1000 / emitted : null,
    nackPerSecond: rate(previous?.nackCount, current.nackCount, elapsedMs, 1000),
    pliPerSecond: rate(previous?.pliCount, current.pliCount, elapsedMs, 1000),
    firPerSecond: rate(previous?.firCount, current.firCount, elapsedMs, 1000),
    freezeCount: current.freezeCount !== undefined && Number.isSafeInteger(current.freezeCount) && current.freezeCount >= 0 ? current.freezeCount : null,
    freezeDurationMs: current.totalFreezesDuration !== undefined && Number.isFinite(current.totalFreezesDuration) && current.totalFreezesDuration >= 0 ? current.totalFreezesDuration * 1000 : null,
    decodedFrames:Number.isSafeInteger(current.framesDecoded)&&current.framesDecoded>=0?current.framesDecoded:null,
    bitrateKbps: rate(previous?.bytesReceived, current.bytesReceived, elapsedMs, 8),
    decodedFps: rate(previous?.framesDecoded, current.framesDecoded, elapsedMs, 1000),
    droppedFrames: dropped,
    jitterMs: current.jitter !== undefined && Number.isFinite(current.jitter) && current.jitter >= 0 ? Math.round(current.jitter * 1000) : null,
    packetsLost: current.packetsLost !== undefined && Number.isFinite(current.packetsLost) && current.packetsLost >= 0 ? current.packetsLost : null,
    packetLossPercent: null,
    rttMs: current.rttMs !== undefined && Number.isFinite(current.rttMs) && current.rttMs >= 0 && current.rttMs <= 60_000
      ? current.rttMs : null,
  }
}
