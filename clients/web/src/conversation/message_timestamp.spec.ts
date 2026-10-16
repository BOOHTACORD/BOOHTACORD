import { describe, expect, it } from 'vitest'
import { messageTimestamp } from './message_timestamp'
describe('message timestamp presentation', () => {
  it('keeps a compact clock and exposes date, seconds and timezone without hover', () => {
    const result = messageTimestamp('2026-10-15T10:07:09Z', 'UTC')
    expect(result.short).toBe('10:07')
    expect(result.full).toContain('15 октября 2026')
    expect(result.full).toContain('10:07:09')
    expect(result.full).toContain('UTC')
  })
  it('formats both labels in the same local timezone', () => {
    const result = messageTimestamp('2026-10-15T23:07:09Z', 'Europe/Istanbul')
    expect(result.short).toBe('02:07')
    expect(result.full).toContain('16 октября 2026')
    expect(result.full).toContain('02:07:09')
  })
})
