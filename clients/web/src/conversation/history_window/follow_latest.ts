interface ScrollMetrics { scrollHeight: number; clientHeight: number; scrollTop: number }

export function shouldPreserveLatestPosition(followingLatest: boolean, viewport: ScrollMetrics): boolean {
  return followingLatest && viewport.scrollHeight - viewport.clientHeight - viewport.scrollTop <= 96
}
