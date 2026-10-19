export type TouchPttCapabilities = { maxTouchPoints: number; coarsePointer: boolean }

export function supportsTouchPtt(capabilities: TouchPttCapabilities): boolean {
  return capabilities.maxTouchPoints > 0 || capabilities.coarsePointer
}

export function browserSupportsTouchPtt(): boolean {
  if (typeof navigator === 'undefined') return false
  return supportsTouchPtt({
    maxTouchPoints: navigator.maxTouchPoints ?? 0,
    coarsePointer: typeof window !== 'undefined' && typeof window.matchMedia === 'function'
      ? window.matchMedia('(pointer: coarse)').matches
      : false,
  })
}
