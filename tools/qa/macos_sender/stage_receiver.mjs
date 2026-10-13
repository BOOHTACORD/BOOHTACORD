import {readFileSync,writeFileSync,existsSync,statSync} from 'node:fs'
import {createHash} from 'node:crypto'
import {dirname,join} from 'node:path'
import {createRequire} from 'node:module'
import assert from 'node:assert/strict'
import {requireReceiverEvidence,requireMetadataEvidence,requireFunctionalEvidence,requireFaultVideoProgress} from './stage_receiver_policy.mjs'
const require=createRequire(new URL('../../../clients/web/package.json',import.meta.url))
const {chromium,expect}=require('@playwright/test')
const input=JSON.parse(readFileSync(process.env.QA_STAGE_INPUT,'utf8'))
const index=Number(process.env.QA_STAGE_INDEX),out=process.env.QA_STAGE_OUT
assert.ok(index>=1&&index<=20)
const report={status:'RUNNING',case:index,scope:'Co-hosted physical native publisher + headless Chromium viewer using existing pinnedSDK baseline',browser_TLS_validation:'Test context ignoreHTTPSErrors, NOT valid-browser-chain acceptance; native exactCA chain separately verified',physical_presentation:'NOT_RUN',thresholdClaims:false}
const browser=await chromium.launch({args:['--autoplay-policy=no-user-gesture-required','--explicitly-allowed-ports=5060']}),context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:900}})
let page,lease,phase='authenticate'
async function api(path,method='GET',body){const r=await context.request.fetch('https://localhost:5060/api/v1'+path,{method,headers:{Origin:'https://localhost:5060','Content-Type':'application/json'},...(body===undefined?{}:{data:body})});assert.ok(r.ok(),`HTTP${r.status()}`);return r.status()===204?null:r.json()}
let closing
async function closeOwned(){
 if(closing)return closing
 closing=(async()=>{const errors=[];if(page)await page.evaluate(()=>window.nativeStage.stop()).catch(e=>errors.push(e.name));if(lease)await api(`/voice/leases/${lease.id}`,'DELETE').then(()=>{lease=null}).catch(e=>errors.push(e.name));await context.close().catch(e=>errors.push(e.name));await browser.close().catch(e=>errors.push(e.name));report.owned_context_closed=true;report.cleanup_errors=errors;writeFileSync(out+'/receiver-'+index+'.json',JSON.stringify(report,null,2)+'\n')})();return closing
}
process.once('SIGTERM',()=>{report.status='FAIL';report.failed_phase=phase;report.error_type='CoordinatorStoppedOwnedViewer';void closeOwned().finally(()=>process.exit(143))})
try{
 phase='fixture navigation preflight';page=await context.newPage();await page.goto('http://127.0.0.1:5066/tests/screen_profile/native_stage.html');await page.waitForFunction(()=>typeof window.nativeStage?.connect==='function');await page.waitForLoadState('networkidle');await page.waitForTimeout(1000);phase='authenticate'
 const metadataRequested=process.env.QA_STAGE_METADATA==='1';let publisherSession
 if(metadataRequested){
  const work=dirname(process.env.QA_STAGE_INPUT),cache=join(work,'stage-publisher-owner-private.json')
  assert.equal(readFileSync(join(work,'.qa98325-owned'),'utf8'),'owned physical Mac QA\n')
  const binding=createHash('sha256').update(readFileSync(join(work,'configuration.json'))).digest('hex')
  if(existsSync(cache)){
   assert.equal(statSync(cache).mode&0o777,0o600);const saved=JSON.parse(readFileSync(cache,'utf8'));assert.equal(saved.configuration_sha256,binding);publisherSession=saved.session
  }else{
   await api('/auth/login','POST',{login:'qa_admin',password:input.password});publisherSession=await api('/auth/session');assert.equal(publisherSession.authenticated,true);assert.ok(publisherSession.account_id)
   writeFileSync(cache,JSON.stringify({configuration_sha256:binding,session:{authenticated:true,account_id:publisherSession.account_id}}),{mode:0o600});await api('/auth/logout','POST')
  }
 }
 if(process.env.QA_STAGE_REGISTER_CONFIRMED!=='1'){
 const registration=await context.request.post('https://localhost:5060/api/v1/auth/register',{headers:{Origin:'https://localhost:5060'},data:{login:'qa_stage_viewer_'+String(index).padStart(2,'0'),password:input.password}});assert.ok([201,409].includes(registration.status()),`Owned fixture registration HTTP${registration.status()}`)
 }
 await api('/auth/login','POST',{login:'qa_stage_viewer_'+String(index).padStart(2,'0'),password:input.password})
 const topology=await api('/channels'),channel=topology.categories.flatMap(c=>c.channels).find(c=>c.name==='QaVoice'&&c.kind==='VOICE');assert.ok(channel)
 const publisherOwner={originId:'https://localhost:5060',accountId:publisherSession?.account_id,roomId:'voice:'+channel.id}
 lease=await api(`/voice/channels/${channel.id}/leases`,'POST',{transfer:true});const credential=await api(`/voice/leases/${lease.id}/credential`,'POST')
 phase='SDK connect';await page.evaluate(c=>window.nativeStage.connect(c),credential)
 report.capabilities=await page.evaluate(()=>window.nativeStage.capabilities());report.browser=browser.version()
 writeFileSync(out+'/receiver-'+index+'-ready.json',JSON.stringify({ready:true,case:index}))
 phase='first callback';report.roomConnectionToFirstCallbackMs=await page.evaluate(()=>window.nativeStage.firstFrame())
 const first=await page.evaluate(()=>window.nativeStage.sample());report.firstFrameEvidence={callbackCount:first.presentedFrameCallbacks,firstFrameId:first.presentedFrameIds.find(value=>value!==null)??null};
 if(process.env.QA_STAGE_FUNCTIONAL==='1'){
  phase='functional metadata and output';report.functionalObservations=[]
  const deadline=Date.now()+55000;let complete=false
  while(Date.now()<deadline){
   const metadata=await page.evaluate(async owner=>{const {parseScreenDescriptor}=await import('/src/voice/screen_profile_metadata/descriptor.ts');return window.nativeStage.metadata(owner,parseScreenDescriptor)},publisherOwner)
   const output=await page.evaluate(async()=>{const s=await window.nativeStage.sample();return {videoAttachmentRevision:s.videoAttachmentRevision,presentedFrameCallbacks:s.presentedFrameCallbacks,numberedFrameObserved:s.presentedFrameIds.some(v=>v!==null)}})
   report.functionalObservations.push({metadata,output})
   try{requireFunctionalEvidence(report.functionalObservations);complete=true;break}catch{}
   await page.waitForTimeout(250)
  }
  assert.equal(complete,true,'Bounded actual lifecycle/metadata/output proof incomplete');await page.screenshot({path:out+'/receiver-'+index+'-synthetic.png'})
  report.functionalLifecycle=true;report.noSteadyFPSClaims=true
 }else{
 phase='warmup';
 if(process.env.QA_METADATA_ISOLATED_FAULT==='1'){report.faultVideoProgress=[];for(let second=0;second<30;second++){const observation=await page.evaluate(async()=>{const sample=await window.nativeStage.sample();return {callbacks:sample.presentedFrameCallbacks,attachment:sample.videoAttachmentRevision}});report.faultVideoProgress.push(observation);await page.waitForTimeout(1000)}requireFaultVideoProgress(report.faultVideoProgress)}else await page.waitForTimeout(30000)
 phase='steady';report.measurement=await page.evaluate(()=>window.nativeStage.collect(60000))
 await page.screenshot({path:out+'/receiver-'+index+'-synthetic.png'})
 requireReceiverEvidence(report,process.env.BOOHTACORD_QA_STATIC==='1')
 }
 if(process.env.QA_STAGE_METADATA==='1'&&process.env.QA_STAGE_FUNCTIONAL!=='1'){
  phase='metadata current parser';
  const readMetadata=()=>page.evaluate(async owner=>{const {parseScreenDescriptor}=await import('/src/voice/screen_profile_metadata/descriptor.ts');return window.nativeStage.metadata(owner,parseScreenDescriptor)},publisherOwner)
  report.metadataCurrent=await readMetadata()
  phase='metadata late viewer reconnect';await page.evaluate(()=>window.nativeStage.stop());const renewed=await api(`/voice/leases/${lease.id}/credential`,'POST');await page.evaluate(c=>window.nativeStage.connect(c),renewed)
  report.lateViewerFirstCallbackMs=await page.evaluate(()=>window.nativeStage.firstFrame());await page.waitForTimeout(1500);report.metadataLateViewer=await readMetadata()
  requireMetadataEvidence(report.metadataCurrent,report.metadataLateViewer,{mode:process.env.QA_METADATA_ISOLATED_FAULT==='1'?'text':process.env.QA_NATIVE_MODE??'motion',profile:'P'+process.env.BOOHTACORD_QA_RESOLUTION+'_'+process.env.BOOHTACORD_QA_FPS})
  report.metadataParserProvenance='Actual current production module with origin/account/room independently obtained from authenticated API session and authorized topology; no additional subscription'
 }
 phase='own stop';await page.evaluate(()=>window.nativeStage.stop());await api(`/voice/leases/${lease.id}`,'DELETE');lease=null
 report.status='PASS';report.flowOnly=true;report.markerCheck=report.functionalLifecycle?'FUNCTIONAL_NUMBERED_OUTPUT':report.measurement.sequence.markerFrames>0?'AVAILABLE':'UNAVAILABLE';report.warmupSeconds=report.functionalLifecycle?null:30;report.steadySeconds=report.functionalLifecycle?null:60
}catch(error){report.status='FAIL';report.failed_phase=phase;report.error_type=error.name;throw error}
finally{await closeOwned()}
