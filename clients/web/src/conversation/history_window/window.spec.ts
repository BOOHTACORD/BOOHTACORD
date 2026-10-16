import { describe, expect, it } from 'vitest'
import { buildVirtualOffsets, findVirtualRange, historyRowGap, type HistoryRow } from './window'

describe('variable-height message history window', () => {
  it.each([50, 500, 5000, 10000])('keeps the rendered range bounded for %i timeline rows', (count) => {
    const rows = Array.from({ length: count }, (_, index) => ({ key: `row-${index}`, kind: index % 11 === 0 ? 'date' as const : 'message' as const, estimate: index % 11 === 0 ? 28 : 90, gap: index % 3 ? 24 : 34 }))
    const heights = new Map(rows.filter((_, index) => index % 3 === 0).map((row, index) => [row.key, index % 2 ? 260 : 72]))
    const offsets = buildVirtualOffsets(rows, heights)
    const range = findVirtualRange(offsets, offsets[Math.floor(count / 2)] ?? 0, 720, 8)

    expect(range.end - range.start).toBeLessThan(40)
    expect(range.top + range.rowsHeight + range.bottom).toBe(offsets[count])
  })

  it('keeps compact spacing distinct at group and day boundaries', () => {
    const previous: HistoryRow = { key: 'message', kind: 'message', estimate: 80, gap: 0 }
    expect(historyRowGap('message')).toBe(0)
    expect(historyRowGap('message', previous, true)).toBe(4)
    expect(historyRowGap('message', previous)).toBe(12)
    expect(historyRowGap('message', previous, false, true)).toBe(10)
    expect(historyRowGap('date', previous)).toBe(16)
    expect(historyRowGap('message', { ...previous, kind: 'date' })).toBe(12)
  })

  it('finds measured variable-height boundaries and preserves spacing classes', () => {
    const rows = ['a', 'b', 'c', 'd'].map((key) => ({ key, estimate: 90, gap: 0 }))
    const offsets = buildVirtualOffsets(rows, new Map([['a', 40], ['b', 140], ['c', 60], ['d', 80]]))
    const attachment: HistoryRow = { key: 'file', kind: 'message', estimate: 90, gap: 0, hasAttachments: true }

    expect(findVirtualRange(offsets, 180, 20, 0)).toMatchObject({ start: 2, end: 3, top: 180, rowsHeight: 60, bottom: 80 })
    expect(historyRowGap('message', attachment)).toBe(12)
    expect(historyRowGap('message', attachment, false, true)).toBe(10)
  })
})
