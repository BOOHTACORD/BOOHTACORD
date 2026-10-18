import { test } from 'node:test'
import assert from 'node:assert/strict'
import { api, priorSessionStatus, loginAccount } from './request.mjs'

test('session revocation carries the explicitly expected account; credentials stay same-origin', async()=>{
  const previous=globalThis.fetch;let request
  globalThis.fetch=async(url,options)=>{request={url,...options};return new Response(null,{status:204})}
  try {
    const page={evaluate:(fn,args)=>fn(args)}
    assert.equal((await api(page,'/me/sessions/test','DELETE',undefined,{'X-Account-ID':'expected-account'})).status,204)
    assert.equal(request.url,'/api/v1/me/sessions/test')
    assert.equal(request.credentials,'same-origin')
    assert.equal(request.headers['X-Account-ID'],'expected-account')
    assert.equal(request.body,undefined)
    await api(page,'/auth/session')
    assert.equal(request.headers['X-Account-ID'],undefined)
  } finally {globalThis.fetch=previous}
})

test('old-cookie denial probes a protected route, never optional auth/session',async()=>{
  let observed
  const page={context:()=>({request:{get:async(url,options)=>{
    observed={url,options};return {status:()=>401}
  }}})}
  assert.equal(await priorSessionStatus(page,'https://localhost:4830','synthetic-cookie'),401)
  assert.equal(observed.url,'https://localhost:4830/api/v1/me/sessions')
  assert.equal(observed.options.headers.Cookie,'synthetic-cookie')
})

test('login honors bounded Retry-After once without weakening authentication',async()=>{
  const previous=globalThis.fetch;let calls=0;const waits=[]
  globalThis.fetch=async()=>++calls===1?new Response('{}',{status:429,headers:{'Retry-After':'180'}}):new Response(null,{status:204})
  try {
    const result=await loginAccount({evaluate:(fn,args)=>fn(args)},'fixture','synthetic',async ms=>waits.push(ms))
    assert.equal(result.status,204);assert.equal(calls,2);assert.deepEqual(waits,[180100])
  } finally {globalThis.fetch=previous}
})

test('absent, excessive or malformed backoff never loops or changes limits',async()=>{
  const previous=globalThis.fetch
  try {
    for(const header of [null,'301','-1','nonsense']){
      let calls=0
      globalThis.fetch=async()=>{calls++;return new Response('{}',{status:429,headers:header===null?{}:{'Retry-After':header}})}
      await assert.rejects(()=>loginAccount({evaluate:(fn,args)=>fn(args)},'fixture','synthetic',async()=>assert.fail('unexpected sleep')))
      assert.equal(calls,1)
    }
  } finally {globalThis.fetch=previous}
})

test('login does not retry invalid credentials',async()=>{
  const previous=globalThis.fetch;let calls=0
  globalThis.fetch=async()=>{calls++;return new Response('{}',{status:401})}
  try {assert.equal((await loginAccount({evaluate:(fn,args)=>fn(args)},'fixture','synthetic')).status,401);assert.equal(calls,1)}
  finally {globalThis.fetch=previous}
})
