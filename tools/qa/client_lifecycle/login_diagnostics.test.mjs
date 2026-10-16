import { test } from 'node:test'
import assert from 'node:assert/strict'
import { withLoginDiagnostics } from './login_diagnostics.mjs'
import { navigateOwnedLoopback, prepareOwnedLoopback } from './loopback_navigation.mjs'

function readinessClock() {
  let time = 0
  return { now: () => time, wait: async ms => { time += ms } }
}
test('auth preparation observes real GET health stability before opening the form', async () => {
  const clock = readinessClock(), calls = []
  const health = 'https://localhost:4810/api/v1/health'
  const page = { goto: async url => {
    calls.push({ url, time: clock.now() })
    return { status: () => 200, url: () => url }
  } }
  await prepareOwnedLoopback(page, 'https://localhost:4810', clock)
  assert.equal(calls.at(-1).url, 'https://localhost:4810')
  const probes = calls.slice(0, -1)
  assert.ok(probes.every(call => call.url === health))
  assert.ok(probes.at(-1).time - probes[0].time >= 3000)
  assert.ok(calls.every(call => !/auth\/(login|register)/.test(call.url)))
})
test('known startup network change resets the read-only stability window', async () => {
  const clock = readinessClock(), healthy = []
  let failedAt = null
  const page = { goto: async url => {
    if (url.endsWith('/health')) {
      if (clock.now() === 1000) {
        failedAt = clock.now()
        throw new Error('net::ERR_NETWORK_CHANGED')
      }
      if (failedAt !== null) healthy.push(clock.now())
    }
    return { status: () => 200, url: () => url }
  } }
  await prepareOwnedLoopback(page, 'https://localhost:4810', clock)
  assert.equal(failedAt, 1000)
  assert.ok(healthy.at(-1) - healthy[0] >= 3000)
})
test('health preparation is bounded and never retries TLS, HTTP failure or a foreign origin', async () => {
  const clock = readinessClock()
  let calls = 0
  await assert.rejects(prepareOwnedLoopback({ goto: async () => {
    calls++; throw new Error('net::ERR_NETWORK_CHANGED')
  } }, 'https://localhost:4810', clock), /did not settle/)
  assert.ok(calls <= 60)
  const tls = new Error('net::ERR_CERT_AUTHORITY_INVALID')
  await assert.rejects(prepareOwnedLoopback({ goto: async () => { throw tls } },
    'https://localhost:4810', readinessClock()), error => error === tls)
  await assert.rejects(prepareOwnedLoopback({ goto: async url => ({ status: () => 503, url: () => url }) },
    'https://localhost:4810', readinessClock()), /health/)
  await assert.rejects(prepareOwnedLoopback({ goto: async () => assert.fail('Foreign GET') },
    'https://foreign.test', readinessClock()), /Owned/)
})

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
test('bootstrap failure before auth controls records session state without credentials', async () => {
  const f = fixture(), original = new Error('authentication control unavailable')
  f.page.locator = selector => ({ selector, count: async () => selector === '.session-state' ? 1 : 0 })
  await assert.rejects(withLoginDiagnostics(f.page, '/owned/.out/1024', async () => {
    f.listeners.get('requestfailed')({ url: () => 'https://localhost:4810/api/v1/auth/session',
      failure: () => ({ errorText: 'net::ERR_NETWORK_CHANGED' }) })
    throw original
  }, value => f.logs.push(value)), error => error === original)
  assert.equal(f.logs[0].session_transport_error, 'network_changed')
  assert.equal(f.logs[0].session_screen_present, true)
  assert.equal(f.logs[0].form_error_present, false)
  assert.equal(f.images[0].mask[0].selector, 'input, textarea')
  assert.equal(f.listeners.size, 0)
})
test('diagnostic capture failure cannot replace the original assertion', async () => {
  const f = fixture(), original = new Error('original assertion')
  f.page.screenshot = async () => { throw new Error('capture unavailable') }
  await assert.rejects(withLoginDiagnostics(f.page, '/owned/.out/1440', async () => { throw original }, () => {}), error => error === original)
})
