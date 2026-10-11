import { test } from 'node:test'
import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import { requests } from './requests.mjs'

const request = path => ({ method: () => 'GET', url: () => 'https://localhost:4810/api/v1/'+path })
test('parallel topology requests remain visible to the acceptance gate', () => {
  const page = new EventEmitter(), meter = requests(page, 'room')
  meter.start()
  const pending = Array.from({ length: 3 }, () => request('channels'))
  pending.forEach(value => page.emit('request', value))
  pending.forEach(value => page.emit('requestfinished', value))
  const result = meter.stop()
  assert.equal(result.max_parallel, 3)
  assert.equal(result.max_parallel_topology, 3)
})
test('all history cursor forms share the resource concurrency budget', () => {
  const page = new EventEmitter(), meter = requests(page, 'room')
  meter.start()
  const pending = ['','?before=old','?after=new'].map(query => request('channels/room/messages'+query))
  pending.forEach(value => page.emit('request', value))
  pending.forEach(value => page.emit('requestfailed', value))
  const result = meter.stop()
  assert.equal(result.history, 3)
  assert.equal(result.max_parallel_history, 3)
  assert.equal(result.max_parallel, 3)
})
