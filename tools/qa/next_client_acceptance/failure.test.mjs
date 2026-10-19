import assert from 'node:assert/strict'
import test from 'node:test'
import { failureSummary } from './failure.mjs'

test('public failure receipt never copies exception text, credentials or resource IDs', () => {
  const privateText = 'PRIVATE-CANARY secret-cookie 12345678-1234-1234-1234-123456789abc'
  for (const error of [new Error(privateText), Object.assign(new Error(privateText), { name: privateText }), privateText]) {
    const result = failureSummary(error)
    assert.match(result, /^FAIL: next-client acceptance \((Error|TimeoutError|AssertionError)\); bounded diagnostics only$/)
    assert.equal(result.includes('PRIVATE'), false)
    assert.equal(result.includes('12345678'), false)
  }
})
