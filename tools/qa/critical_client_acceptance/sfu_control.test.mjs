import { test } from 'node:test'
import assert from 'node:assert/strict'
import { controlOwnedSfu } from './sfu_control.mjs'

const owner = 'qa-client-0123456789abcdef'
test('a pending SFU stop keeps the browser driver event loop responsive', async () => {
  let finish, stopping = false
  const pending = new Promise(resolve => { finish = resolve })
  const calls = []
  const execute = async (program, args) => {
    calls.push([program, args])
    if (args[0] === 'inspect') return { stdout: owner+'\n' }
    stopping = true
    await pending
    return { stdout: '' }
  }
  const operation = controlOwnedSfu('stop', { owner, execute })
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(stopping, true)
  finish()
  await operation
  assert.deepEqual(calls[1], ['docker', ['stop', owner+'-sfu']])
})
test('a foreign container cannot be stopped or started', async () => {
  let calls = 0
  const execute = async () => { calls++; return { stdout: 'foreign-owner\n' } }
  await assert.rejects(controlOwnedSfu('start', { owner, execute }), /Foreign/)
  assert.equal(calls, 1)
})
test('invalid ownership or an unexpected action never executes a command', async () => {
  const execute = async () => { assert.fail('No command is permitted') }
  await assert.rejects(controlOwnedSfu('stop', { owner: 'foreign', execute }))
  await assert.rejects(controlOwnedSfu('rm', { owner, execute }))
})
