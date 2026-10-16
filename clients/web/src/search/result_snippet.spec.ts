import { describe, expect, it } from 'vitest'
import { searchResultSnippet } from './result_snippet'
describe('search result excerpts', () => {
  it('shows a late match with nearby context instead of the start of a long body', () => {
    const result = searchResultSnippet('prefix '.repeat(100) + 'Orbit nearby context', 'orbit')
    expect(result.filter(part => part.match).map(part => part.value)).toEqual(['Orbit'])
    const text = result.map(part => part.value).join('')
    expect(text.startsWith('…')).toBe(true)
    expect(text).toContain('nearby context')
    expect(Array.from(text).length).toBeLessThanOrEqual(242)
  })
  it('keeps every case-insensitive match in a short result', () => {
    expect(searchResultSnippet('Orbit orbit ORBIT', 'orbit').filter(part => part.match).map(part => part.value)).toEqual(['Orbit', 'orbit', 'ORBIT'])
  })
  it('treats query punctuation literally', () => {
    expect(searchResultSnippet('prefix a+b? suffix', 'a+b?').filter(part => part.match).map(part => part.value)).toEqual(['a+b?'])
  })
  it('does not split emoji into surrogate halves when taking a bounded excerpt', () => {
    const parts = searchResultSnippet('😀'.repeat(300) + 'орбита ' + '🚀'.repeat(300), 'орбита')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['орбита'])
    const text = parts.map(part => part.value).join('')
    expect(Array.from(text).some(point => point.length === 1 && point.charCodeAt(0) >= 0xd800 && point.charCodeAt(0) <= 0xdfff)).toBe(false)
    expect(Array.from(text).length).toBeLessThanOrEqual(242)
  })
  it('maps expanded lowercase code points back to the original text', () => {
    const parts = searchResultSnippet('İ '.repeat(100) + 'ОРБИТА', 'орбита')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['ОРБИТА'])
  })
  it('retains the whole maximum-length query in the excerpt', () => {
    const query = 'я'.repeat(256)
    const parts = searchResultSnippet('prefix '.repeat(100) + query + ' tail '.repeat(100), query)
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual([query])
    expect(Array.from(parts.map(part => part.value).join('')).length).toBeLessThanOrEqual(350)
  })
  it('does not anchor a whole-word server hit on an earlier partial word', () => {
    const parts = searchResultSnippet('orbital '.repeat(100) + 'Orbit nearby', 'orbit')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Orbit'])
    expect(parts.map(part => part.value).join('')).toContain('nearby')
  })
  it('normalizes query whitespace alongside displayed message whitespace', () => {
    const parts = searchResultSnippet('prefix '.repeat(100) + 'Orbit   launch nearby', 'orbit   launch')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Orbit launch'])
    expect(parts.map(part => part.value).join('')).toContain('nearby')
  })
  it('anchors a multiword full-text result on its first positive term when words are separated', () => {
    const parts = searchResultSnippet('prefix '.repeat(100) + 'Launch tomorrow; Orbit follows.', 'orbit launch')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Launch', 'Orbit'])
    expect(parts.map(part => part.value).join('')).toContain('tomorrow')
  })
  it('finds a quoted web-search phrase without requiring literal quotes in the message', () => {
    const parts = searchResultSnippet('prefix '.repeat(100) + 'Orbit launch nearby', '"orbit launch"')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Orbit launch'])
  })
  it('ignores OR and negative terms when selecting fallback context', () => {
    const parts = searchResultSnippet('hidden order launchpad '.repeat(100) + 'Saturn nearby', 'orbit OR saturn -hidden')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Saturn'])
    expect(parts.map(part => part.value).join('')).toContain('nearby')
  })
  it('ignores a negated quoted phrase when selecting fallback context', () => {
    const parts = searchResultSnippet('hidden phrase '.repeat(100) + 'Orbit nearby', 'orbit -"hidden phrase"')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Orbit'])
  })
  it('matches fallback words at Unicode word boundaries and preserves composed text', () => {
    const parts = searchResultSnippet('launchpad орбитальный '.repeat(100) + 'Орбита launch', 'орбита launch')
    expect(parts.filter(part => part.match).map(part => part.value)).toEqual(['Орбита launch'])
    const separated = searchResultSnippet('launchpad орбитальный '.repeat(100) + 'Орбита nearby launch', 'орбита launch')
    expect(separated.filter(part => part.match).map(part => part.value)).toEqual(['Орбита', 'launch'])
  })
  it('renders formatted content and link destinations as readable, noninteractive preview text', () => {
    const text = searchResultSnippet('**Bold** [site](https://example.org/path)\n\n```\ncode\n```', '').map(part => part.value).join('')
    expect(text).toBe('Bold site (https://example.org/path) code')
  })
  it('bounds an unmatched query and leaves short and empty messages intact', () => {
    expect(searchResultSnippet('short', 'absent')).toEqual([{ value: 'short', match: false }])
    expect(searchResultSnippet('', '')).toEqual([])
    expect(Array.from(searchResultSnippet('x'.repeat(1000), 'absent').map(part => part.value).join('')).length).toBeLessThanOrEqual(242)
  })
})
