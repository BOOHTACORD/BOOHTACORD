import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { evaluateNotificationPolicy, type PolicyInput, type PolicyResult } from './policy'

const fixture = JSON.parse(readFileSync(new URL('../../../../../contracts/notification-policy-v1.fixtures.json', import.meta.url), 'utf8')) as {
  version: number; cases: { name: string; input: PolicyInput; expected: PolicyResult }[]
}
describe('shared notification policy v1', () => {
  it('uses the shared versioned corpus', () => { expect(fixture.version).toBe(1); expect(fixture.cases.length).toBeGreaterThanOrEqual(25) })
  for (const test of fixture.cases) it(test.name, () => expect(evaluateNotificationPolicy(test.input)).toEqual(test.expected))
})
