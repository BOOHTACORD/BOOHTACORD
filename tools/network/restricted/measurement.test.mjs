import { test } from 'node:test'
import assert from 'node:assert/strict'
import { transportReady, observation } from './measurement.mjs'
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
