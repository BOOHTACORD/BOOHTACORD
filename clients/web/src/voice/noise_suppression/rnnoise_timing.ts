/** Missing browser diagnostics must not prevent processing. */
export function captureRate(track: MediaStreamTrack): number | undefined {
  try {
    const rate = track.getSettings?.().sampleRate
    return rate !== undefined && Number.isSafeInteger(rate) && rate > 0 && rate <= 384000 ? rate : undefined
  } catch { return undefined }
}

export function initializationDuration(started: number): number | undefined {
  const duration = performance.now() - started
  return Number.isFinite(duration) && duration >= 0 && duration <= 60000 ? duration : undefined
}
