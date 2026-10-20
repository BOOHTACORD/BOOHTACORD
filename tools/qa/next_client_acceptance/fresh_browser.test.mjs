import assert from 'node:assert/strict'
import test from 'node:test'
import { freshBrowser } from './fresh_browser.mjs'

test('independent upload cases leave the changed network in the old browser process', async () => {
  const calls = [], cookies = [{ name: 'session', value: 'opaque', domain: 'localhost', secure: true, httpOnly: true }]
  const old = { context: { cookies: async () => { calls.push('cookies'); return cookies } }, close: async () => calls.push('close-old') }
  const fresh = { context: { addCookies: async value => { assert.equal(value, cookies); calls.push('restore-cookies') } }, close: async () => calls.push('close-new') }
  const result = await freshBrowser(old, async () => { calls.push('new-native-browser'); return fresh })
  assert.equal(result, fresh)
  assert.deepEqual(calls, ['cookies', 'close-old', 'new-native-browser', 'restore-cookies'])
})

test('failed cookie transfer closes the replacement instead of reusing changed transport', async () => {
  let closed = false
  const old = { context: { cookies: async () => [] }, close: async () => {} }
  const fresh = { context: { addCookies: async () => { throw Error('transfer failed') } }, close: async () => { closed = true } }
  await assert.rejects(freshBrowser(old, async () => fresh), /transfer failed/)
  assert.equal(closed, true)
})

test('failed old-browser cleanup prevents another browser from starting', async () => {
  let created = false
  const old = { context: { cookies: async () => [] }, close: async () => { throw Error('cleanup failed') } }
  await assert.rejects(freshBrowser(old, async () => { created = true }), /cleanup failed/)
  assert.equal(created, false)
})
