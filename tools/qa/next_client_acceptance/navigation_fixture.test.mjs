import assert from 'node:assert/strict'
import test from 'node:test'
import { navigationFixture } from './navigation_fixture.mjs'

test('navigation receives a fresh scope and preserves unread restoration fixture/state', async () => {
  const unread=Object.freeze({category:'owned-category',a:'prior-unread',b:'other',member:'member',admin:'admin'})
  let count=0
  const create=async()=>`navigation-${++count}`
  const seeded=[]
  const seed=(fixture,kind)=>{seeded.push([fixture.a,kind,fixture.member]);return {ids:Array.from({length:121},(_,i)=>`row-${i}`)}}
  const [first,second]=await Promise.all([navigationFixture(unread,create,seed,async(_,id)=>id),navigationFixture(unread,create,seed,async(_,id)=>id)])
  assert.equal(unread.a,'prior-unread')
  assert.notEqual(first.a,second.a)
  assert.notEqual(first.a,unread.a)
  assert.deepEqual(seeded,[['navigation-1','CHANNEL','member'],['navigation-2','CHANNEL','member']])
  assert.equal(first.admin,unread.admin)
})

test('scope reuse or incomplete history fails instead of weakening navigation coverage', async () => {
  const previous={category:'owned',a:'unread'}
  for(const ids of [[],Array(121).fill('duplicate'),['one']]) {
    await assert.rejects(()=>navigationFixture(previous,async()=> 'fresh',()=>({ids})))
  }
  await assert.rejects(()=>navigationFixture(previous,async()=> 'unread',()=>({ids:[]})))
})

test('failed creation never seeds a different scope and failed seed never returns a PASS fixture', async () => {
  let seeded=false
  await assert.rejects(()=>navigationFixture({a:'prior'},async()=>{throw Error('controlled')},()=>{seeded=true}))
  assert.equal(seeded,false)
  await assert.rejects(()=>navigationFixture({a:'prior'},async()=> 'fresh',()=>{throw Error('controlled')}))
})

test('the isolated scope recreates the prior read baseline before unseen-tail checks', async () => {
  const ids=Array.from({length:121},(_,i)=>`row-${i}`)
  const order=[]
  await navigationFixture({a:'unread'},async()=> 'fresh',()=>{order.push('seed');return {ids}},async(fixture,id)=>{
    order.push('cursor');assert.equal(fixture.a,'fresh');assert.equal(id,'row-120');return id
  })
  assert.deepEqual(order,['seed','cursor'])
  await assert.rejects(()=>navigationFixture({a:'unread'},async()=> 'fresh',()=>({ids}),async()=> 'wrong'))
  await assert.rejects(()=>navigationFixture({a:'unread'},async()=> 'fresh',()=>({ids}),async()=>{throw Error('controlled')}))
})
