import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { readFileSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { randomBytes } from 'node:crypto'
import https from 'node:https'
import { performance } from 'node:perf_hooks'
import { api, priorSessionStatus, loginAccount } from './request.mjs'

const require=createRequire(new URL('../../../clients/web/package.json',import.meta.url))
const {chromium}=require('@playwright/test')
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const origin='https://localhost:4830', contexts=[]
const report={issue:59,status:'RUNNING',rows:[],browser:null}
let phase='browser startup', browser, password=input.password
function save(){report.phase=phase;writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')}
async function waitFor(action,accept,timeout=45000){const end=Date.now()+timeout;while(Date.now()<end){const value=await action();if(accept(value))return value;await new Promise(r=>setTimeout(r,200))}throw new Error('Bounded observation timed out')}
async function client(){const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:900,height:600}});contexts.push(context);const page=await context.newPage();await page.goto(origin);return page}
const status=(r,expected)=>{report.last_http_status=r.status;report.expected_http_status=expected;assert.equal(r.status,expected);return r.body}
async function login(page,name,pw=input.password){status(await loginAccount(page,name,pw,undefined,seconds=>{report.rate_limit_waits??=[];report.rate_limit_waits.push(seconds);save();console.log('POC03_RATE_WAIT '+seconds)}),204)}
async function lease(page,channel,transfer=false){return status(await api(page,`/voice/channels/${channel}/leases`,'POST',{transfer}),201)}
async function credential(page,id){return status(await api(page,`/voice/leases/${id}/credential`,'POST',{}),200)}
async function connect(page,cred){await page.evaluate(c=>window.connectMedia(c.url,c.token),cred)}
function sql(query){return execFileSync('docker',['exec',input.owner+'-db','psql','-U','qa','-d','qa','-tAc',query],{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim()}
function uuid(value){assert.match(value,/^[a-f0-9-]{36}$/);return value}
function worker(id){return JSON.parse(sql(`SELECT json_build_object('worker_confirmed',r.completed_at IS NOT NULL,'worker_attempts',r.attempt_count,'logical_revoked',l.revoked_at IS NOT NULL) FROM voice_leases l JOIN voice_sfu_revocations r ON r.lease_id=l.id WHERE l.id='${uuid(id)}'` )||'null')}
function unexpired(token){return JSON.parse(Buffer.from(token.split('.')[1],'base64url')).exp>Date.now()/1000+5}
async function replay(token){return new Promise((resolve,reject)=>{
  const url=new URL('/rtc',origin);url.searchParams.set('access_token',token);url.searchParams.set('protocol','15');url.searchParams.set('sdk','js')
  const request=https.request(url,{ca:readFileSync(input.ca),headers:{Connection:'Upgrade',Upgrade:'websocket','Sec-WebSocket-Version':'13','Sec-WebSocket-Key':randomBytes(16).toString('base64')}},response=>{response.resume();resolve(response.statusCode)})
  request.on('upgrade',(_response,socket)=>{socket.destroy();resolve(101)})
  request.on('error',reject);request.setTimeout(8000,()=>request.destroy(new Error('Handshake timed out')));request.end()
})}
async function block(admin,id,blocked){const accounts=status(await api(admin,'/admin/accounts'),200).accounts;const account=accounts.find(a=>a.account_id===id);assert.ok(account);return api(admin,'/admin/accounts/'+id,'PATCH',{role:'MEMBER',blocked,expected_updated_at:account.updated_at})}

try {
  browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required']});report.browser=browser.version();save()
  const admin=await client();await login(admin,'qa_admin')
  phase='synthetic accounts'
  const account=status(await api(admin,'/auth/register','POST',{login:'qa_revoke_presenter',password}),201)
  status(await api(admin,'/auth/register','POST',{login:'qa_revoke_observer',password}),201)
  const category=status(await api(admin,'/admin/categories','POST',{name:'POC03'}),201)
  const observer=await client();await login(observer,'qa_revoke_observer')
  for(const name of ['kick','ban','logout','session_revoke','password_reset','transfer','close']){
    phase=name+': prepare actual media';save();console.log('POC03_PHASE '+phase)
    const channel=status(await api(admin,`/admin/categories/${category.id}/channels`,'POST',{name:'POC03 '+name,kind:'VOICE'}),201)
    const presenter=await client();await login(presenter,'qa_revoke_presenter',password)
    const priorCookie=(await presenter.context().cookies()).filter(c=>c.name==='vp_session').map(c=>c.name+'='+c.value).join('; ');assert.ok(priorCookie)
    await observer.reload()
    const pl=await lease(presenter,channel.id),ol=await lease(observer,channel.id)
    const pc=await credential(presenter,pl.id),oc=await credential(observer,ol.id)
    phase=name+': positive API handshake control';save()
    const apiControl=await replay(pc.token);assert.equal(apiControl,101)
    await connect(observer,oc);await connect(presenter,pc)
    const sdk=await waitFor(()=>presenter.evaluate(()=>window.media.refreshed),v=>typeof v==='string'&&v!==pc.token,65000)
    // Positive raw probes take over the same SFU identity. Perform both before
    // publishing, then establish the final real SDK connection/media precondition.
    await presenter.evaluate(()=>window.disposeMedia())
    phase=name+': positive refreshed SDK handshake control';save()
    const sdkControl=await replay(sdk);assert.equal(sdkControl,101)
    await presenter.reload();await connect(presenter,pc);await presenter.evaluate(()=>window.publishSynthetic())
    const before=await waitFor(()=>observer.evaluate(()=>window.mediaObservation()),v=>v.decoded_frames>2&&v.audio_packets>2)
    assert.ok(unexpired(pc.token)&&unexpired(sdk))
    await observer.screenshot({path:input.directory+'/'+name+'-receiving.png'})
    phase=name+': authoritative revoke';save();const started=performance.now(),actionAt=new Date().toISOString();let action,control,nextLease,resetPayload
    if(name==='kick') action=await api(admin,`/admin/accounts/${account.id}/voice-kick`,'POST',{})
    if(name==='ban') action=await block(admin,account.id,true)
    if(name==='logout') action=await api(presenter,'/auth/logout','POST',{})
    if(name==='session_revoke'){
      control=await client();await login(control,'qa_revoke_presenter',password)
      const session=status(await api(presenter,'/me/sessions'),200).sessions.find(s=>s.current)
      action=await api(control,'/me/sessions/'+session.id,'DELETE',undefined,{'X-Account-ID':account.id})
    }
    if(name==='password_reset'){
      const link=status(await api(admin,'/admin/password-reset-links','POST',{account_id:account.id}),201)
      resetPayload={token:new URLSearchParams(new URL(link.url).hash.slice(1)).get('token'),password:password+'N'}
      action=await api(admin,'/auth/password-reset/complete','POST',resetPayload);password=resetPayload.password
    }
    if(name==='transfer'){
      const destination=status(await api(admin,`/admin/categories/${category.id}/channels`,'POST',{name:'POC03 destination',kind:'VOICE'}),201)
      action=await api(presenter,`/voice/channels/${destination.id}/leases`,'POST',{transfer:true});nextLease=status(action,201);assert.ok(nextLease.transferred&&nextLease.id!==pl.id)
    }
    if(name==='close'){
      const topology=status(await api(admin,'/channels'),200)
      action=await api(admin,`/admin/voice-channels/${channel.id}/close-admission`,'POST',{expected_revision:topology.revision,confirm_close:true})
    }
    assert.ok(action.status>=200&&action.status<300)
    phase=name+': worker and media teardown';save()
    const confirmed=await waitFor(()=>Promise.resolve(worker(pl.id)),v=>v?.worker_confirmed&&v.logical_revoked)
    await waitFor(()=>presenter.evaluate(()=>window.media.disconnected),v=>v===true)
    const after=await waitFor(()=>observer.evaluate(()=>window.mediaObservation()),v=>v.removed>=2&&(name!=='close'||!v.observer_connected))
    const delay=Math.round(performance.now()-started)
    assert.equal(after.observer_connected,name!=='close')
    phase=name+': independent unexpired credential replays';save()
    assert.ok(unexpired(pc.token)&&unexpired(sdk))
    const apiStatus=await replay(pc.token),sdkStatus=await replay(sdk)
    assert.equal(apiStatus,403);assert.equal(sdkStatus,403)
    const old=await api(presenter,`/voice/leases/${pl.id}/credential`,'POST',{});assert.ok([401,403,404,409].includes(old.status))
    const priorSession=await priorSessionStatus(presenter,origin,priorCookie)
    const expectedSession=['ban','logout','session_revoke','password_reset'].includes(name)?401:200
    assert.equal(priorSession,expectedSession)
    const observerLease=await api(observer,`/voice/leases/${ol.id}/credential`,'POST',{})
    assert.equal(observerLease.status,name==='close'?409:200)
    if(name==='ban'){assert.ok([401,403].includes((await api(presenter,'/auth/login','POST',{login:'qa_revoke_presenter',password})).status));status(await block(admin,account.id,false),200)}
    if(name==='password_reset')assert.equal((await api(admin,'/auth/password-reset/complete','POST',resetPayload)).status,400)
    if(name==='kick')nextLease=await lease(presenter,channel.id)
    if(nextLease){assert.notEqual(nextLease.id,pl.id);const fresh=await credential(presenter,nextLease.id);await presenter.reload();await connect(presenter,fresh);assert.equal(await presenter.evaluate(()=>window.media.room.state),'connected');status(await api(presenter,`/voice/leases/${nextLease.id}`,'DELETE'),204)}
    if(name==='close')await waitFor(async()=>status(await api(admin,`/admin/voice-channels/${channel.id}/closure`),200),v=>['room_empty','finalized'].includes(v.phase)&&v.pending_revocations===0)
    await observer.screenshot({path:input.directory+'/'+name+'-revoked.png'})
    report.rows.push({case:name,status:'PASS',decoded_frames:before.decoded_frames,audio_packets:before.audio_packets,presenter_disconnected:true,observer_track_removed:true,worker_confirmed:true,observer_connected:after.observer_connected,refreshed_sdk_credential:true,api_replay_status:apiStatus,sdk_replay_status:sdkStatus,api_control_status:apiControl,sdk_control_status:sdkControl,credentials_unexpired:true,old_credential_status:old.status,revoke_delay_ms:delay,worker_attempts:confirmed.worker_attempts,action_at:actionAt,action_status:action.status,prior_session_status:priorSession,observer_lease_status:observerLease.status})
    await presenter.evaluate(()=>window.disposeMedia());await presenter.context().close()
    await observer.evaluate(()=>window.disposeMedia())
    if(name!=='close')status(await api(observer,`/voice/leases/${ol.id}`,'DELETE'),204)
    if(control)await control.context().close()
    console.log('POC03_PASS '+name);save()
  }
  report.status='PASS'
} catch(error){report.status='FAIL';report.failure_phase=phase;report.error_type=error?.name||'Error';if(['number','boolean'].includes(typeof error?.actual))report.error_actual=error.actual;if(['number','boolean'].includes(typeof error?.expected))report.error_expected=error.expected;process.exitCode=1}
finally {for(const context of contexts)await context.close().catch(()=>{});await browser?.close();save()}
