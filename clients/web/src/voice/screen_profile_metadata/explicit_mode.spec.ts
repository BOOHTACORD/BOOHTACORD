import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { parseScreenDescriptor } from './descriptor'

const fixtures = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8'))
const owner = { originId: 'origin-a', accountId: 'account-a', roomId: 'room-a' }

describe('explicit sender content scenario shared contract', () => {
  for (const row of fixtures.descriptorCases) {
    it(row.name, () => {
      const value = { ...structuredClone(fixtures.validDescriptor), ...row.overrides }
      const parsed = parseScreenDescriptor(JSON.stringify(value), owner)
      expect(Boolean(parsed)).toBe(row.accepted)
      if (row.accepted) expect(parsed?.mode).toBe(value.mode)
    })
  }
})
