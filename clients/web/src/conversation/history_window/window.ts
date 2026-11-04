export interface WindowRange { start: number; end: number; top: number; rowsHeight: number; bottom: number }
export interface HistoryRow { key: string; kind: 'date' | 'message'; messageId?: string; estimate: number; gap: number; hasAttachments?: boolean; grouped?: boolean }
export type RenderedRow<T extends HistoryRow = HistoryRow> = T & { index: number; pinned: boolean; detached?: boolean }

export function buildVirtualOffsets<T extends { key: string; estimate: number; gap: number }>(rows: readonly T[], measured: ReadonlyMap<string, number>): number[] {
  const offsets = new Array<number>(rows.length + 1)
  offsets[0] = 0
  rows.forEach((row, index) => { offsets[index + 1] = offsets[index]! + (measured.get(row.key) ?? row.estimate) + row.gap })
  return offsets
}

function rowAt(offsets: readonly number[], position: number): number {
  let low = 0, high = Math.max(0, offsets.length - 2)
  while (low < high) {
    const middle = Math.floor((low + high) / 2)
    if (offsets[middle + 1]! <= position) low = middle + 1
    else high = middle
  }
  return low
}

export function findVirtualRange(offsets: readonly number[], scrollTop: number, viewportHeight: number, overscan = 8): WindowRange {
  const count = Math.max(0, offsets.length - 1)
  if (!count) return { start: 0, end: 0, top: 0, rowsHeight: 0, bottom: 0 }
  const first = rowAt(offsets, Math.max(0, scrollTop))
  const last = rowAt(offsets, Math.max(0, scrollTop) + Math.max(1, viewportHeight)) + 1
  const start = Math.max(0, first - overscan), end = Math.min(count, last + overscan)
  const top = offsets[start]!, rowsHeight = offsets[end]! - top
  return { start, end, top, rowsHeight, bottom: offsets[count]! - offsets[end]! }
}

export function historyRowGap(kind: HistoryRow['kind'], previous?: HistoryRow, grouped = false, compact = false): number {
  if (!previous) return 0
  if (kind === 'date') return 16
  if (previous.kind === 'date') return 12
  if (grouped) return 4
  return compact ? 10 : 12
}
