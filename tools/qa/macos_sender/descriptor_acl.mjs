// Real disposable API/SFU acceptance. Credentials and raw attributes stay local.
import assert from 'node:assert/strict'
import {readFileSync, writeFileSync} from 'node:fs'
import {createRequire} from 'node:module'

const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
const {chromium} = require('@playwright/test')
const input = JSON.parse(readFileSync(process.env.QA_STAGE_INPUT, 'utf8'))
const fixture = JSON.parse(readFileSync(new URL('../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8')).validDescriptor
const origin = 'https://localhost:5060'
const existingFixture = process.env.QA_DESCRIPTOR_ACL_EXISTING_FIXTURE
assert.ok(existingFixture === undefined || existingFixture === '1', 'Explicit owned existing fixture only')
const report = {schema_version: 1, status: 'RUNNING', scope: 'Real disposable Go/PostgreSQL/LiveKit ACL and revision acceptance; no capture or hardware claim', browser_TLS_validation: 'Owned test context ignoreHTTPSErrors; not browser trust-chain acceptance', checks: [], cleanup_errors: []}
const browser = await chromium.launch({args: ['--explicitly-allowed-ports=5060']})
const actors = []
let anonymous, phase = 'setup'

async function request(actor, path, method = 'GET', body, requestOrigin = origin) {
  try { return await actor.context.request.fetch(origin + '/api/v1' + path, {
    method, timeout: 10000, maxRedirects: 0,
    headers: {Origin: requestOrigin, 'Content-Type': 'application/json'},
    ...(body === undefined ? {} : {data: body}),
  }) } catch (error) {
    report.request_failure = {method, path_kind: path.replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, ':owned-id'), codes: ['ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'CERT_HAS_EXPIRED', 'ERR_TLS_CERT_ALTNAME_INVALID', 'UNABLE_TO_VERIFY_LEAF_SIGNATURE'].filter(code => String(error.message).includes(code))}
    throw error
  }
}
async function json(actor, path, method = 'GET', body) {
  const response = await request(actor, path, method, body)
  if (!response.ok()) report.setup_failure = {actual_HTTP: response.status(), retry_after_seconds: /^\d+$/.test(response.headers()['retry-after'] ?? '') ? Number(response.headers()['retry-after']) : null}
  assert.ok(response.ok(), `Setup HTTP${response.status()}`)
  return response.status() === 204 ? null : response.json()
}
async function check(name, actor, lease, descriptor, expected, requestOrigin = origin) {
  phase = name
  const response = await request(actor, `/voice/leases/${lease}/screen-profile/v1`, 'PUT', descriptor, requestOrigin)
  report.checks.push({name, status: response.status() === expected ? 'PASS' : 'FAIL', expected_HTTP: expected, actual_HTTP: response.status()})
  assert.equal(response.status(), expected, name)
  if (expected === 204) {
    assert.match(response.headers()['cache-control'] ?? '', /no-store/)
    assert.equal(response.headers()['x-screen-profile-operation-revision'], String(descriptor.scope.operation_revision))
  }
}
async function observe(observer, owner) {
  return observer.page.evaluate(owner => window.nativeStage.metadata(owner, (raw, expected) => {
    if (!raw) return undefined
    try {
      const value = JSON.parse(raw), scope = value.scope
      if (value.schema_version !== 1 || scope?.origin_id !== expected.originId || scope?.account_id !== expected.accountId || scope?.room_id !== expected.roomId) return undefined
      return value
    } catch { return undefined }
  }), owner)
}
async function waitForRevision(observer, owner, revision) {
  const deadline = Date.now() + 10000
  while (Date.now() < deadline) {
    const value = await observe(observer, owner)
    if (value.descriptor?.operation_revision === revision) return value
    await observer.page.waitForTimeout(100)
  }
  throw new Error('OwnedAttributeDeadline')
}
async function createActor(suffix) {
  phase = 'setup_' + suffix + '_context'
  const actor = {context: await browser.newContext({ignoreHTTPSErrors: true}), lease: null, page: null, loggedIn: false}
  actors.push(actor)
  if (existingFixture !== '1') {
    phase = 'setup_' + suffix + '_admin_login'
    await json(actor, '/auth/login', 'POST', {login: 'qa_admin', password: input.password})
    actor.loggedIn = true
    const registration = await request(actor, '/auth/register', 'POST', {login: 'qa_descriptor_acl_' + suffix, password: input.password})
    assert.equal(registration.status(), 201, 'Fresh owned fixture registration required; retries explicitly reuse this same fixture')
    await json(actor, '/auth/logout', 'POST')
  }
  phase = 'setup_' + suffix + '_fixture_login'
  await json(actor, '/auth/login', 'POST', {login: 'qa_descriptor_acl_' + suffix, password: input.password})
  actor.loggedIn = true
  const session = await json(actor, '/auth/session')
  assert.equal(session.authenticated, true)
  actor.account = session.account_id
  const topology = await json(actor, '/channels')
  const channel = topology.categories.flatMap(value => value.channels).find(value => value.name === 'QaVoice' && value.kind === 'VOICE')
  assert.ok(channel, 'OwnedVoiceFixturePresent')
  actor.owner = {originId: origin, accountId: actor.account, roomId: 'voice:' + channel.id}
  actor.lease = await json(actor, `/voice/channels/${channel.id}/leases`, 'POST', {transfer: true})
  const credential = await json(actor, `/voice/leases/${actor.lease.id}/credential`, 'POST')
  actor.page = await actor.context.newPage()
  await actor.page.goto('http://127.0.0.1:5066/tests/screen_profile/native_stage.html')
  await actor.page.evaluate(credential => window.nativeStage.connect(credential), credential)
  return actor
}

try {
  const a = await createActor('a'), b = await createActor('b')
  anonymous = {context: await browser.newContext({ignoreHTTPSErrors: true})}
  const descriptor = structuredClone(fixture)
  descriptor.scope.operation_revision = 1
  descriptor.scope.publication_generation = 1
  // Deliberately noncanonical body IDs: server must derive ownership from cookie/lease.
  await check('foreign_origin', a, a.lease.id, descriptor, 403, 'https://foreign.invalid')
  await check('missing_origin', a, a.lease.id, descriptor, 403, '')
  await check('no_session_cookie', anonymous, a.lease.id, descriptor, 401)
  await check('cross_account_lease', b, a.lease.id, descriptor, 404)
  await check('own_valid_update', a, a.lease.id, descriptor, 204)
  const received = await waitForRevision(b, a.owner, 1)
  assert.equal(received.descriptorValidForIndependentOwner, true)
  assert.equal(received.rejectsForeignOwnerScopes, true)
  assert.equal(received.subscribedVideoCount, 0)
  report.checks.push({name: 'real_SFU_server_canonical_scope', status: 'PASS', subscribed_video_count: 0, source: 'Real participant metadata/attributes; independently read account/channel. Minimal test scope parser, not production Web parser acceptance.'})
  await check('identical_retry', a, a.lease.id, descriptor, 204)
  const conflict = structuredClone(descriptor)
  conflict.mode = 'text'
  await check('same_revision_changed_payload', a, a.lease.id, conflict, 409)
  descriptor.scope.operation_revision = 2
  descriptor.mode = 'text'
  await check('explicit_text60_new_revision', a, a.lease.id, descriptor, 204)
  await waitForRevision(b, a.owner, 2)
  const stale = structuredClone(descriptor)
  stale.scope.operation_revision = 1
  await check('stale_revision', a, a.lease.id, stale, 409)
  const afterReject = await observe(b, a.owner)
  assert.equal(afterReject.descriptor.operation_revision, 2)
  assert.equal(afterReject.descriptor.mode, 'text')
  assert.equal(afterReject.subscribedVideoCount, 0)
  report.checks.push({name: 'rejected_requests_keep_current_SFU_attribute', status: 'PASS', subscribed_video_count: 0})
  const revokedLease = a.lease.id
  await json(a, `/voice/leases/${revokedLease}`, 'DELETE')
  a.lease = null
  descriptor.scope.operation_revision = 3
  await check('revoked_lease', a, revokedLease, descriptor, 404)
  const liveLease = b.lease.id
  await json(b, '/auth/logout', 'POST')
  b.loggedIn = false
  b.lease = null // Logout owns server-side revocation; context disposal follows.
  await check('revoked_authenticated_session', b, liveLease, descriptor, 401)
  report.status = 'PASS'
} catch (error) {
  report.status = 'FAIL'
  report.failed_phase = phase
  report.error_type = error.name
  process.exitCode = 1
} finally {
  for (const actor of actors) {
    if (actor.page) await actor.page.evaluate(() => window.nativeStage.stop()).catch(error => report.cleanup_errors.push(error.name))
    if (actor.lease) await json(actor, `/voice/leases/${actor.lease.id}`, 'DELETE').catch(error => report.cleanup_errors.push(error.name))
    if (actor.loggedIn) await json(actor, '/auth/logout', 'POST').catch(error => report.cleanup_errors.push(error.name))
    await actor.context.close().catch(error => report.cleanup_errors.push(error.name))
  }
  await anonymous?.context.close().catch(error => report.cleanup_errors.push(error.name))
  await browser.close().catch(error => report.cleanup_errors.push(error.name))
  report.owned_contexts_closed = true
  report.synthetic_accounts = 'Disposable fixture accounts remain only until owned stack destruction.'
  if (report.cleanup_errors.length) { report.status = 'FAIL'; process.exitCode = 1 }
  writeFileSync(process.env.QA_DESCRIPTOR_ACL_OUT, JSON.stringify(report, null, 2) + '\n')
}
