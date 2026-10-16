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
  type Range = { start: number; end: number }
  const word = (point: string | undefined) => Boolean(point && /[\p{L}\p{N}\p{M}_]/u.test(point))
  function matches(needle: string, wholeWord = false): Range[] {
    const found: Range[] = []
    if (!needle) return found
    for (let index = folded.indexOf(needle); index !== -1; index = folded.indexOf(needle, index + needle.length)) {
      const start = offsets[index]!, end = offsets[index + needle.length - 1]! + 1
      if (!wholeWord || !word(points[start - 1]) && !word(points[end])) found.push({ start, end })
    }
    return found
  }
  const normalized = query.replace(/\s+/gu, ' ').trim().toLocaleLowerCase()
  const queryPoints = Array.from(normalized)
  let ranges = matches(normalized, word(queryPoints[0]) || word(queryPoints.at(-1)))
  // The server uses websearch_to_tsquery('simple'): separate positive words,
  // quoted phrases, OR and exclusions can produce hits without a literal query.
  // These are display hints, not a replacement for server query/ACL evaluation.
  if (!ranges.length) {
    const needles = new Set<string>()
    for (const group of normalized.matchAll(/(-?)(?:"([^"]+)"|(\S+))/gu)) {
      const phrase = group[2], token = group[3] ?? ''
      if (group[1] || !phrase && token === 'or') continue
      if (phrase) needles.add(phrase)
      for (const term of (phrase ?? token).match(/[\p{L}\p{N}\p{M}_]+/gu) ?? []) needles.add(term)
    }
    const found = [...needles].flatMap(needle => matches(needle, true)).sort((a, b) => a.start - b.start || b.end - a.end)
    ranges = []
    for (const range of found) {
      const previous = ranges.at(-1)
      if (previous && range.start < previous.end) previous.end = Math.max(previous.end, range.end)
      else ranges.push(range)
    }
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
