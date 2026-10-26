import { test } from 'node:test'
import assert from 'node:assert/strict'
import { transportReady, observation } from './measurement.mjs'
import { fixtureStartup } from './startup.mjs'
const report = () => ({ outcome: 'connected', signalMs: 1, sdkJoinMs: 2, iceObservedMs: 3,
  firstRtpObservedMs: 4, transports: [{ selected: true, protocol: 'tcp', audioBytesSent: 40, audioBytesReceived: 80 }] })
test('both roles require observed RTP on the selected required transport', () => {
  assert.equal(transportReady(report(), 'tcp', 'sender'), true)
  assert.equal(transportReady(report(), 'tcp', 'receiver'), true)
  assert.equal(transportReady(report(), 'udp', 'sender'), false)
})
test('a receiver with packets cannot stand in for an unobserved sender', () => {
  const sender = report(); sender.firstRtpObservedMs = null
  assert.equal(transportReady(sender, 'tcp', 'sender'), false)
  assert.equal(transportReady(report(), 'tcp', 'receiver'), true)
})
test('inactive or wrong transport bytes never satisfy the required route', () => {
  const value = report(); value.transports[0].audioBytesSent = 0
  value.transports.push({ selected: true, protocol: 'udp', audioBytesSent: 800 })
  assert.equal(transportReady(value, 'tcp', 'sender'), false)
  value.transports[0].selected = false; value.transports[0].audioBytesSent = 20
  assert.equal(transportReady(value, 'tcp', 'sender'), false)
})
test('missing, failed and incomplete timing remains not ready', () => {
  assert.equal(transportReady(null, 'tcp', 'sender'), false)
  for (const field of ['signalMs', 'sdkJoinMs', 'iceObservedMs', 'firstRtpObservedMs']) {
    const value = report(); value[field] = null
    assert.equal(transportReady(value, 'tcp', 'sender'), false)
  }
  assert.equal(transportReady({ ...report(), outcome: 'failed' }, 'tcp', 'sender'), false)
})
test('observation allows no raw candidate, token or payload fields', () => {
  const value = { ...report(), token: 'private-token', candidateId: 'private-candidate', address: 'private-address' }
  const observed = observation(value, 'tcp', 'sender')
  assert.equal(observed.ready, true)
  assert.doesNotMatch(JSON.stringify(observed), /private|token|candidate|address/)
})

test('HTTP readiness waits for transformed fixture and its static import graph', async () => {
  let transform, idle, reachedIdle = false, nextCalls = 0
  const startup = fixtureStartup({
    transformRequest: () => new Promise(resolve => { transform = resolve }),
    waitForRequestsIdle: () => { reachedIdle = true; return new Promise(resolve => { idle = resolve }) },
  })
  const response = () => ({ statusCode:200, headers:{}, end(){}, setHeader(k,v){this.headers[k]=v} })
  const check = () => { const r=response(); startup.middleware({url:'/tests/restricted_networks/fixture.html'},r,()=>nextCalls++); return r }
  const warming = startup.warm()
  assert.equal(check().statusCode,503)
  transform({code:'fixture'}); await new Promise(resolve=>setImmediate(resolve))
  assert.equal(reachedIdle,true); assert.equal(check().statusCode,503)
  idle(); await warming
  assert.equal(check().headers['X-Restricted-Fixture-Ready'],'modules-warmed')
  assert.equal(nextCalls,1)
})

test('missing or failed fixture transform never opens the readiness gate', async () => {
  for (const fail of [false,true]) {
    const startup=fixtureStartup({transformRequest:async()=>{if(fail)throw new Error('compile failed');return null},waitForRequestsIdle:async()=>{}})
    await assert.rejects(startup.warm())
    const response={statusCode:200,end(){}}
    startup.middleware({url:'/tests/restricted_networks/fixture.html'},response,()=>assert.fail('premature readiness'))
    assert.equal(response.statusCode,503)
  }
})
