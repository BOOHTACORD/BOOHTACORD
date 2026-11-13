/** Never stack the research engine on an unconfirmed browser NS state. */
export function browserSuppressionDisabled(track: MediaStreamTrack | undefined): boolean {
  try { return track?.getSettings?.()?.noiseSuppression === false } catch { return false }
}
