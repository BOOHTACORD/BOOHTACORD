import assert from 'node:assert/strict'
import {readFileSync,writeFileSync} from 'node:fs'
import {chromium,expect} from '../client_lifecycle/request.mjs'
const privateInput=JSON.parse(readFileSync(process.env.QA_NATIVE_PRIVATE_INPUT,'utf8'))
const report={issue:327,status:'RUNNING',method:'Physical macOS native publisher controlled by separate owner; actual Go/SFU and production registry/controller/diagnostics in isolated Vite observer. Not full production Web-bundle or quality benchmark.',physical_native_sender:true,receiver:'headless Chromium source-module fixture',actual_api:true,actual_sfu:true,mocks:false,hardware_quality:'NOT_RUN',checks:{}}
const browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required','--explicitly-allowed-ports=5060']}),c=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:900}})
let page,lease,phase='setup'
async function api(path,method='GET',body){const r=await c.request.fetch('https://localhost:5060/api/v1'+path,{method,headers:{Origin:'https://localhost:5060','Content-Type':'application/json'},...(body===undefined?{}:{data:body})});assert.ok(r.ok(),`HTTP ${r.status()}`);return r.status()===204?null:r.json()}
try{
 await api('/auth/login','POST',{login:'qa_admin',password:privateInput.password})
 await api('/auth/register','POST',{login:'qa327_native_observer',password:privateInput.password})
 await api('/auth/logout','POST')
 await api('/auth/login','POST',{login:'qa327_native_observer',password:privateInput.password})
 const topology=await api('/channels'),channel=topology.categories.flatMap(v=>v.channels).find(v=>v.name==='QaVoice'&&v.kind==='VOICE');assert.ok(channel)
 lease=await api(`/voice/channels/${channel.id}/leases`,'POST',{transfer:false});const credential=await api(`/voice/leases/${lease.id}/credential`,'POST')
 page=await c.newPage();await page.goto('http://127.0.0.1:5087/tests/track_name/fixture.html');await page.evaluate(v=>window.qa327.connect(v.url,v.token),credential)
 phase='discover native publication';await expect.poll(()=>page.evaluate(()=>window.qa327.snapshot().streams),{timeout:90000}).toBe(1)
 const before=await page.evaluate(()=>window.qa327.snapshot());assert.equal(before.descriptor_present,false);assert.equal(before.provenance,'legacy-track-name');assert.ok(before.target);assert.equal(before.SDK_trackName_present,true);assert.equal(before.legacy_name_present,false);assert.equal(before.subscriptions,0);assert.equal(before.active_video_outputs,0);report.before_selection=before;report.checks.native_trackName_profile_before_subscription='PASS'
 phase='select actual native source';await page.getByRole('button',{name:'Выбрать источник',exact:true}).click();await expect.poll(()=>page.evaluate(()=>window.qa327.snapshot().active_video_outputs),{timeout:30000}).toBe(1);await expect.poll(()=>page.evaluate(()=>window.qa327.snapshot().decoded_frames),{timeout:30000}).toBeGreaterThan(0)
 await page.locator('.stream-diagnostics > summary').click();await expect(page.getByText('Профиль при запуске · имя дорожки',{exact:true})).toBeVisible();await expect(page.getByText(before.target,{exact:true})).toBeVisible();await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:process.env.QA_NATIVE_OUT+'/physical-native-legacy-desktop.png'});report.checks.native_profile_rendered_with_legacy_provenance='PASS'
 const selected=await page.evaluate(()=>window.qa327.snapshot());assert.equal(selected.subscriptions,1);assert.equal(selected.active_video_outputs,1);assert.ok(selected.width>0&&selected.height>0);report.selected=selected
 await page.getByRole('button',{name:'Выбрать источник',exact:true}).click();const repeated=await page.evaluate(()=>window.qa327.snapshot());assert.equal(repeated.subscriptions,1);assert.equal(repeated.active_video_outputs,1);report.checks.one_renderer_and_no_repeat_subscription='PASS'
 await page.setViewportSize({width:393,height:900});await expect(page.getByText('Профиль при запуске · имя дорожки',{exact:true})).toBeVisible();await page.screenshot({path:process.env.QA_NATIVE_OUT+'/physical-native-legacy-mobile.png'});report.checks.mobile_native_profile_provenance_visible='PASS'
 await page.evaluate(()=>window.qa327.stop());await api(`/voice/leases/${lease.id}`,'DELETE');lease=null;report.checks.own_observer_leave_cleanup='PASS';report.browser=browser.version();report.status='PASS'
}catch(e){report.status='FAIL';report.failed_phase=phase;report.error_type=e?.name;throw e}finally{if(page)await page.evaluate(()=>window.qa327.stop()).catch(()=>{});if(lease)await api(`/voice/leases/${lease.id}`,'DELETE').catch(()=>{});await c.close();await browser.close();writeFileSync(process.env.QA_NATIVE_OUT+'/scenario.json',JSON.stringify(report,null,2)+'\n')}
