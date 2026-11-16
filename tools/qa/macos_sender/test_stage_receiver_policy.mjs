import test from 'node:test'
import assert from 'node:assert/strict'
import {requireReceiverEvidence,requireMetadataEvidence,requireFunctionalEvidence,requireFaultVideoProgress,requireNativeWebTelemetryEvidence,isNativeScreenTelemetryEvent,observeNativeScreenTelemetry} from './stage_receiver_policy.mjs'
test('staticfirstframe can succeed withzero steadycallbacks, never unknownmarker',()=>{
 const report={roomConnectionToFirstCallbackMs:12,firstFrameEvidence:{callbackCount:1,firstFrameId:0},measurement:{presentation:{frameCallbacks:0}}}
 assert.equal(requireReceiverEvidence(report,true),true)
 assert.throws(()=>requireReceiverEvidence({...report,firstFrameEvidence:{callbackCount:1,firstFrameId:null}},true))
 assert.throws(()=>requireReceiverEvidence(report,false))
})

test('metadata acceptance requires independently scoped production parser, foreign negatives and unchanged single subscription',()=>{
 const valid={attributePresent:true,descriptorValidForIndependentOwner:true,rejectsForeignOwnerScopes:true,subscribedVideoCount:1,descriptor:{mode:'text',requested_profile_id:'P1080_60',publisher_state:'sharing'}}
 assert.equal(requireMetadataEvidence(valid,valid,{mode:'text',profile:'P1080_60'}),true)
 for(const bad of [{...valid,attributePresent:false},{...valid,descriptorValidForIndependentOwner:false},{...valid,rejectsForeignOwnerScopes:false},{...valid,subscribedVideoCount:2},{...valid,descriptor:{...valid.descriptor,mode:'motion'}}])assert.throws(()=>requireMetadataEvidence(bad,valid,{mode:'text',profile:'P1080_60'}))
 assert.throws(()=>requireMetadataEvidence(valid,{...valid,descriptorValidForIndependentOwner:false},{mode:'text',profile:'P1080_60'}))
})

test('Mac functional flow requires compatible mode plus separately restarted lower/higher captures and fresh lease output',()=>{
 const row=(profile,generation,operation,profileRevision,attachment,publication,mode='motion',fps=60,width=1920)=>({metadata:{attributePresent:true,descriptorValidForIndependentOwner:true,rejectsForeignOwnerScopes:true,subscribedVideoCount:1,publicationObservationRevision:publication,descriptor:{mode,requested_profile_id:profile,publication_generation:generation,operation_revision:operation,profile_revision:profileRevision,layers:[{width,height:width===1280?720:1080,max_fps:fps}]}},output:{videoAttachmentRevision:attachment,presentedFrameCallbacks:10,numberedFrameObserved:true}})
 const rows=[row('P1080_60',1,1,2,1,1),row('P1080_60',1,2,3,1,1,'text'),row('P720_30',2,1,4,2,2,'motion',30,1280),row('P1080_60',3,1,5,3,3),row('P1080_60',4,1,6,4,4)]
 assert.equal(requireFunctionalEvidence(rows),true)
 assert.throws(()=>requireFunctionalEvidence([rows[0],rows[1],row('P720_30',1,3,4,1,1),...rows.slice(3)]))
 assert.throws(()=>requireFunctionalEvidence(rows.filter((_,i)=>i!==1)))
 assert.throws(()=>requireFunctionalEvidence(rows.map(r=>({...r,output:{...r.output,videoAttachmentRevision:1}}))))
 assert.throws(()=>requireFunctionalEvidence(rows.map(r=>({...r,metadata:{...r.metadata,publicationObservationRevision:1}}))))
 assert.throws(()=>requireFunctionalEvidence(rows.map(r=>({...r,output:{...r.output,numberedFrameObserved:false}}))))
})

test('isolated fault must retain actually increasing decoded callbacks throughout sampled intervals',()=>{
 assert.equal(requireFaultVideoProgress([{callbacks:1},{callbacks:10},{callbacks:30}]),true)
 for(const rows of [[],[{callbacks:1}],[{callbacks:3},{callbacks:3}],[{callbacks:3},{callbacks:2}],[{callbacks:null},{callbacks:3}]])assert.throws(()=>requireFaultVideoProgress(rows))
})

test('native macOS telemetry pairing requires an authenticated Web viewer, scoped realtime event and fresh selected sender sample',()=>{
 const valid={status:'PASS',scope:'Native sender to selected Web viewer; flow only',sender_platform:'macos',sender_client:'flutter',web_session_authenticated:true,voice_connected:true,selected_stream_decoded:true,realtime_event_count:1,scoped_native_event:true,fresh_sender_sample_visible:true,target_labeled_separately:true,no_sensitive_fields_in_receipt:true}
 assert.equal(requireNativeWebTelemetryEvidence(valid),true)
 for(const bad of [
  {...valid,web_session_authenticated:false},
  {...valid,voice_connected:false},
  {...valid,selected_stream_decoded:false},
  {...valid,realtime_event_count:0},
  {...valid,scoped_native_event:false},
  {...valid,fresh_sender_sample_visible:false},
  {...valid,target_labeled_separately:false},
  {...valid,sender_platform:'web'},
  {...valid,sender_client:'web'},
  {...valid,raw_identifiers_or_payloads_stored:true},
  {...valid,raw_track_sid:'forbidden'},
 ])assert.throws(()=>requireNativeWebTelemetryEvidence(bad))
})

test('native telemetry scope is observed as a boolean without retaining event identifiers',()=>{
 const event={kind:'screen_telemetry.updated',payload:{owner_lease_id:'11111111-1111-4111-8111-111111111111',server_received_at:'2026-11-16T12:00:00Z',envelope:{schema_version:1,media_session_id:'qa_session_1',publication_generation:1,platform:'macos',client_kind:'flutter',capability_version:1,sequence:1}}}
 assert.equal(isNativeScreenTelemetryEvent(event),true)
 for(const bad of [
  {...event,kind:'screen_viewers.changed'},
  {...event,payload:{...event.payload,envelope:{...event.payload.envelope,platform:'web'}}},
  {...event,payload:{...event.payload,envelope:{...event.payload.envelope,client_kind:'web'}}},
  {...event,payload:{...event.payload,envelope:{...event.payload.envelope,publication_generation:0}}},
  {...event,payload:{...event.payload,envelope:{...event.payload.envelope,capability_version:17}}},
  {...event,payload:{...event.payload,envelope:{...event.payload.envelope,sequence:'1'}}},
  {...event,payload:{...event.payload,server_received_at:'yesterday'}},
  {...event,payload:{...event.payload,owner_lease_id:'private-id'}},
 ])assert.equal(isNativeScreenTelemetryEvent(bad),false)
})

test('native telemetry observer records only the scoped-event boolean in its receipt',()=>{
 const event={kind:'screen_telemetry.updated',payload:{owner_lease_id:'11111111-1111-4111-8111-111111111111',server_received_at:'2026-11-16T12:00:00Z',envelope:{schema_version:1,media_session_id:'qa_session_1',publication_generation:1,platform:'macos',client_kind:'flutter',capability_version:1,sequence:1}}}
 const report={scoped_native_event:false}
 assert.equal(observeNativeScreenTelemetry(report,event),true)
 assert.deepEqual(report,{scoped_native_event:true})
 const invalid={scoped_native_event:false}
 assert.equal(observeNativeScreenTelemetry(invalid,{...event,payload:{...event.payload,envelope:{...event.payload.envelope,platform:'web'}}}),false)
 assert.deepEqual(invalid,{scoped_native_event:false})
})
