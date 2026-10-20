import assert from 'node:assert/strict'
import test from 'node:test'
import { mkdtempSync, mkdirSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { failureSummary, failureContext, captureFailure } from './failure.mjs'

test('public failure receipt never copies exception text, credentials or resource IDs', () => {
  const privateText = 'PRIVATE-CANARY secret-cookie 12345678-1234-1234-1234-123456789abc'
  for (const error of [new Error(privateText), Object.assign(new Error(privateText), { name: privateText }), privateText]) {
    const result = failureSummary(error)
    assert.match(result, /^FAIL: next-client acceptance \((Error|TimeoutError|AssertionError)\); bounded diagnostics only$/)
    assert.equal(result.includes('PRIVATE'), false)
    assert.equal(result.includes('12345678'), false)
  }
})

test('failure context retains only an allowed stage and source frame coordinates', () => {
  const error = Object.assign(new Error('PRIVATE-CANARY'), { stack: [
    'Error: PRIVATE-CANARY',
    '    at navigation (file:///private/build/tools/qa/next_client_acceptance/navigation.mjs:65:10)',
    '    at private_user (file:///private/build/node_modules/private.mjs:9:2)',
    '    at unknown (file:///private/build/tools/qa/next_client_acceptance/private.mjs:1:1)',
    '    at file:///private/build/tools/qa/next_client_acceptance/scenario.mjs:38:11',
  ].join('\n') })
  assert.deepEqual(failureContext(error, 'navigation'), {
    schema_version: 1, status: 'FAIL', stage: 'navigation', failure_type: 'Error',
    frames: [{ module: 'navigation.mjs', line: 65, column: 10 }, { module: 'scenario.mjs', line: 38, column: 11 }],
  })
  assert.equal(JSON.stringify(failureContext(error, 'PRIVATE-CANARY')).includes('PRIVATE'), false)
})

test('failure context bounds frame count and accepts unavailable or hostile stacks', () => {
  assert.equal(failureContext(null, 'browser-launch').frames.length, 0)
  assert.equal(failureContext({ stack: {} }, 'navigation').frames.length, 0)
  const stack = Array(20).fill(' at file:///build/tools/qa/next_client_acceptance/navigation.mjs:1:2').join('\n')
  assert.equal(failureContext({ stack }, 'navigation').frames.length, 8)
})

test('stage survives a failed DOM capture and foreign output is rejected', async () => {
  const original = process.cwd(), temporary = mkdtempSync(join(tmpdir(), 'qa-next-failure-'))
  try {
    process.chdir(temporary)
    mkdirSync('.out/next-client-acceptance', { recursive: true })
    await assert.rejects(captureFailure({}, '/foreign', Error('PRIVATE-CANARY'), 'unread'))
    await assert.rejects(captureFailure({ evaluate: async () => { throw Error('PRIVATE-CANARY') } },
      '.out/next-client-acceptance', Error('PRIVATE-CANARY'), 'unread'))
    const value = JSON.parse(readFileSync('.out/next-client-acceptance/browser-failure.json', 'utf8'))
    assert.equal(value.stage, 'unread')
    assert.equal(JSON.stringify(value).includes('PRIVATE'), false)
  } finally { process.chdir(original); rmSync(temporary, { recursive: true, force: true }) }
})
