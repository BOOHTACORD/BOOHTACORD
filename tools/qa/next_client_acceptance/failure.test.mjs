import assert from 'node:assert/strict'
import test from 'node:test'
import { failureSummary, failureLocation } from './failure.mjs'

test('public failure receipt never copies exception text, credentials or resource IDs', () => {
  const privateText = 'PRIVATE-CANARY secret-cookie 12345678-1234-1234-1234-123456789abc'
  for (const error of [new Error(privateText), Object.assign(new Error(privateText), { name: privateText }), privateText]) {
    const result = failureSummary(error)
    assert.match(result, /^FAIL: next-client acceptance \((Error|TimeoutError|AssertionError)\); bounded diagnostics only$/)
    assert.equal(result.includes('PRIVATE'), false)
    assert.equal(result.includes('12345678'), false)
  }
})

test('failure locations retain only an owned source basename and bounded line', () => {
  const error = { name: 'TimeoutError', stack: 'PRIVATE-CANARY secret-cookie\n    at unread (file:///private/account/tools/qa/next_client_acceptance/unread.mjs:42:7)' }
  assert.equal(failureLocation(error), 'unread.mjs:42')
  assert.equal(failureSummary(error), 'FAIL: next-client acceptance (TimeoutError); bounded diagnostics only; source=unread.mjs:42')
  assert.equal(failureSummary(error).includes('PRIVATE'), false)
  assert.equal(failureSummary(error).includes('/private/account'), false)
})

test('unknown paths, unbounded lines and message text are never copied as locations', () => {
  for (const stack of [undefined, 'PRIVATE-CANARY',
    '    at /private/PRIVATE-CANARY.mjs:42:7',
    '    at /tools/qa/next_client_acceptance/unread.mjs:0:7',
    '    at /tools/qa/next_client_acceptance/unread.mjs:10000:7',
    '    at /tools/qa/next_client_acceptance/unread.mjs:42:7?secret-cookie']) {
    assert.equal(failureLocation({ stack }), 'unknown')
  }
})
