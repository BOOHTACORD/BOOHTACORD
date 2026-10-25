import { expect, it } from 'vitest'
import { notificationUTC } from './utc'
it('rejects normalized invalid calendar dates and non UTC aliases', () => {
  expect(Number.isFinite(notificationUTC('2028-02-29T12:01:02.123456789Z'))).toBe(true)
  for (const value of ['2026-02-29T12:01:02Z', '2026-04-31T12:01:02Z', '2026-01-01T25:00:00Z', '2026-01-01', '2026-01-01T00:00:00+01:00', '0000-01-01T00:00:00Z']) expect(Number.isNaN(notificationUTC(value)), value).toBe(true)
})
