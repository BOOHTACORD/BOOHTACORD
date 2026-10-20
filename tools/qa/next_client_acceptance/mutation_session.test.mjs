import assert from 'node:assert/strict'
import test from 'node:test'
import { EventEmitter } from 'node:events'
import { PassThrough, Writable } from 'node:stream'
import { mutationSession } from './mutation_session.mjs'

const container = 'a'.repeat(64), account = '58bfae98-5284-412f-ba24-f2267593f864'
function processFixture() {
  const child = new EventEmitter(), statements = []
  child.stdout = new PassThrough()
  child.stdin = new Writable({ write(chunk, _, done) {
    const value=chunk.toString();statements.push(value)
    queueMicrotask(() => child.stdout.write(value.includes("'ready'") ? 'ready\n' : 'done\n'))
    done()
  }, final(done) { queueMicrotask(() => child.emit('exit',0));done() } })
  child.kill = () => child.emit('exit',1)
  return { child, statements }
}
test('prepare one owned connection before the TTL window and acknowledge every committed mutation', async () => {
  const fixture=processFixture(), calls=[]
  const session=await mutationSession(container,account,(...args)=>{calls.push(args);return fixture.child})
  assert.equal(fixture.statements.length,1)
  for(const action of ['block','unblock','revoke']) await session.mutate(action)
  await session.close()
  assert.equal(calls.length,1)
  assert.deepEqual(calls[0][1].slice(0,4),['exec','-i',container,'psql'])
  assert.equal(calls[0][1].some(value=>value.includes(account)),false)
  assert.match(fixture.statements[1],/blocked_at=now\(\)/)
  assert.match(fixture.statements[2],/blocked_at=NULL/)
  assert.match(fixture.statements[3],/revoked_at=now\(\), revocation_reason='KICK'/)
})
test('foreign identities and actions fail before they can reach SQL', async () => {
  const fixture=processFixture()
  await assert.rejects(mutationSession('foreign',account,()=>fixture.child))
  await assert.rejects(mutationSession(container,'injected',()=>fixture.child))
  const session=await mutationSession(container,account,()=>fixture.child)
  await assert.rejects(session.mutate('foreign'))
  assert.equal(fixture.statements.length,1)
  await session.close()
})
test('unexpected private output rejects with a static error and closes the process', async () => {
  const fixture=processFixture()
  fixture.child.stdin._write=(_chunk,_encoding,done)=>{queueMicrotask(()=>fixture.child.stdout.write('PRIVATE-CANARY\n'));done()}
  await assert.rejects(mutationSession(container,account,()=>fixture.child), error=>{
    assert.equal(error.message,'Owned mutation session failed');return true
  })
})
