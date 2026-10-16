import { test } from 'node:test'
import assert from 'node:assert/strict'
import { withLoginDiagnostics } from './login_diagnostics.mjs'
import { navigateOwnedLoopback } from './loopback_navigation.mjs'

test('owned initial GET tolerates one transient browser network change', async () => {
  let calls = 0
  const page = { goto: async url => {
    assert.equal(url, 'https://localhost:4810')
    if (++calls === 1) throw new Error('page.goto: net::ERR_NETWORK_CHANGED')
    return 'loaded'
  } }
  assert.equal(await navigateOwnedLoopback(page, 'https://localhost:4810'), 'loaded')
  assert.equal(calls, 2)
})
test('initial GET retries remain bounded and never bypass TLS or foreign origins', async () => {
  let calls = 0
  const original = new Error('page.goto: net::ERR_NETWORK_CHANGED')
  const page = { goto: async () => { calls++; throw original } }
  await assert.rejects(navigateOwnedLoopback(page, 'https://localhost:4810'), e => e === original)
  assert.equal(calls, 3)
  calls = 0
  const tls = new Error('page.goto: net::ERR_CERT_AUTHORITY_INVALID')
  await assert.rejects(navigateOwnedLoopback({ goto: async () => { calls++; throw tls } },
    'https://localhost:4810'), e => e === tls)
  assert.equal(calls, 1)
  await assert.rejects(navigateOwnedLoopback(page, 'https://foreign.test'))
  assert.equal(calls, 1)
})

function fixture() {
  const listeners = new Map(), images = [], logs = []
  const page = {
    on: (name, fn) => listeners.set(name, fn),
    off: (name, fn) => { assert.equal(listeners.get(name), fn); listeners.delete(name) },
    locator: selector => ({ selector, count: async () => selector === '#authentication-error' ? 1 : 0 }),
    getByTestId: name => ({ count: async () => 0 }),
    screenshot: async options => images.push(options),
  }
  return { page, listeners, images, logs }
}
test('failed login retains only bounded statuses and masks all editable fields', async () => {
  const f = fixture(), original = new Error('original assertion')
  await assert.rejects(withLoginDiagnostics(f.page, '/owned/.out/1440', async () => {
    const response = f.listeners.get('response')
    response({ url: () => 'https://localhost:4810/api/v1/auth/login?private=secret', status: () => 200 })
    response({ url: () => 'https://localhost:4810/api/v1/auth/session', status: () => 503 })
    response({ url: () => 'https://foreign.test/api/v1/auth/login', status: () => { assert.fail('Foreign status') } })
    throw original
  }, value => f.logs.push(value)), error => error === original)
  assert.deepEqual(f.logs, [{ login_status: 200, session_status: 503,
    login_transport_error: null, session_transport_error: null,
    workspace_present: false, form_error_present: true, session_screen_present: false }])
  assert.equal(f.images[0].mask[0].selector, 'input, textarea')
  assert.ok(!JSON.stringify(f.logs).includes('secret'))
  assert.equal(f.listeners.size, 0)
})
test('failed requests retain only endpoint and allowlisted browser transport codes', async () => {
  const f = fixture(), original = new Error('original assertion')
  await assert.rejects(withLoginDiagnostics(f.page, '/owned/.out/1440', async () => {
    const failed = f.listeners.get('requestfailed')
    failed({ url: () => 'https://localhost:4810/api/v1/auth/login?token=SECRET',
      failure: () => ({ errorText: 'net::ERR_NETWORK_CHANGED' }) })
    failed({ url: () => 'https://localhost:4810/api/v1/auth/session',
      failure: () => ({ errorText: 'arbitrary PRIVATE local path' }) })
    failed({ url: () => 'https://foreign.test/api/v1/auth/login',
      failure: () => { assert.fail('Foreign failure read') } })
    throw original
  }, value => f.logs.push(value)), e => e === original)
  assert.equal(f.logs[0].login_transport_error, 'network_changed')
  assert.equal(f.logs[0].session_transport_error, 'other')
  assert.ok(!/SECRET|PRIVATE|foreign/.test(JSON.stringify(f.logs)))
  assert.equal(f.listeners.size, 0)
})
test('successful login returns normally without diagnostic output or screenshot', async () => {
  const f = fixture()
  assert.equal(await withLoginDiagnostics(f.page, '/owned/.out/1440', async () => 'ok', value => f.logs.push(value)), 'ok')
  assert.equal(f.images.length, 0)
  assert.equal(f.logs.length, 0)
  assert.equal(f.listeners.size, 0)
})
test('diagnostic capture failure cannot replace the original assertion', async () => {
  const f = fixture(), original = new Error('original assertion')
  f.page.screenshot = async () => { throw new Error('capture unavailable') }
  await assert.rejects(withLoginDiagnostics(f.page, '/owned/.out/1440', async () => { throw original }, () => {}), error => error === original)
})
