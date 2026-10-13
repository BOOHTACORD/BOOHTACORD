import type { ScreenFrameRate, ScreenResolution } from './media_publishing'

export type ScreenShareQualityMode = 'motion' | 'text'
export type ScreenShareQualitySelection = {
  mode: ScreenShareQualityMode
  resolution: ScreenResolution
  frameRate: ScreenFrameRate
}

export function normalizeScreenQualitySelection(
  selection: ScreenShareQualitySelection,
): ScreenShareQualitySelection {
  if (selection.resolution === 1440 && selection.frameRate === 60) {
    return { ...selection, frameRate: 30 }
  }
  return selection
}

export function selectScreenQualityResolution(
  current: ScreenShareQualitySelection,
  resolution: ScreenResolution,
): ScreenShareQualitySelection {
  return normalizeScreenQualitySelection({ ...current, resolution })
}

export function selectScreenQualityMode(
  current: ScreenShareQualitySelection,
  mode: ScreenShareQualityMode,
): ScreenShareQualitySelection {
  return normalizeScreenQualitySelection({ ...current, mode })
}
