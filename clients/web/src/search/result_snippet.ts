import { formatMessage } from '../conversation/message_body/message_format'

export interface SearchSnippetPart { value: string; match: boolean }

// A result is a preview with one context action. Links stay in the full message,
// rather than remaining focusable outside the clipped excerpt.
export function searchResultSnippet(body: string, query: string): SearchSnippetPart[] {
  const plain = formatMessage(body).map(block => block.kind === 'CODE_BLOCK' ? block.value
    : block.spans.map(span => span.kind === 'LINK' ? `${span.value} (${span.href})` : span.value).join('')).join(' ').replace(/\s+/gu, ' ').trim()
  const points = Array.from(plain), offsets: number[] = []
  let folded = ''
  points.forEach((point, index) => {
    const lower = point.toLocaleLowerCase()
    folded += lower
    for (let unit = 0; unit < lower.length; unit++) offsets.push(index)
  })
  const needle = query.trim().toLocaleLowerCase(), ranges: { start: number; end: number }[] = []
  if (needle) for (let index = folded.indexOf(needle); index !== -1; index = folded.indexOf(needle, index + needle.length)) {
    const start = offsets[index]!, end = offsets[index + needle.length - 1]! + 1
    if (!ranges.length || start >= ranges.at(-1)!.end) ranges.push({ start, end })
  }
  const first = ranges[0], start = first ? Math.max(0, first.start - 16) : 0
  const budget = Math.max(240, first ? first.end - first.start + 80 : 0), end = Math.min(points.length, start + budget)
  const result: SearchSnippetPart[] = []
  const push = (value: string, match = false) => { if (value) result.push({ value, match }) }
  if (start) push('…')
  let cursor = start
  for (const range of ranges) {
    if (range.end <= cursor) continue
    if (range.start >= end) break
    const left = Math.max(cursor, range.start), right = Math.min(end, range.end)
    push(points.slice(cursor, left).join(''))
    push(points.slice(left, right).join(''), true)
    cursor = right
  }
  push(points.slice(cursor, end).join(''))
  if (end < points.length) push('…')
  return result
}
