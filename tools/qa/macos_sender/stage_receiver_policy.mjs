import assert from 'node:assert/strict'
export function requireReceiverEvidence(report,staticScene=false){
 assert.ok(Number.isFinite(report.roomConnectionToFirstCallbackMs)&&report.roomConnectionToFirstCallbackMs>=0,'Fresh first callback unavailable')
 if(staticScene){
  const first=report.firstFrameEvidence
  assert.ok(first?.callbackCount>=1&&Number.isInteger(first.firstFrameId)&&first.firstFrameId>=0&&first.firstFrameId<4096,'Staticinitialnumberedframe unavailable')
 }else assert.ok(report.measurement.presentation.frameCallbacks>0,'No motion callback evidence')
 return true
}

export function requireMetadataEvidence(current,late,expected){
 for(const row of [current,late]){
  assert.equal(row?.attributePresent,true,'Current SFU descriptor attribute missing')
  assert.equal(row.descriptorValidForIndependentOwner,true,'Production parser rejected independent API owner scope')
  assert.equal(row.rejectsForeignOwnerScopes,true,'Foreign owner/origin/room accepted')
  assert.equal(row.subscribedVideoCount,1,'Metadata must preserve one video subscription')
  assert.equal(row.descriptor?.mode,expected.mode,'Applied mode differs requested mode')
  assert.equal(row.descriptor?.requested_profile_id,expected.profile,'Applied requested profile differs case')
  assert.equal(row.descriptor?.publisher_state,'sharing','Publisher not currently sharing')
 }
 return true
}

export function requireFunctionalEvidence(observations){
 const proofs=observations.filter(r=>r.metadata?.attributePresent&&r.metadata.descriptorValidForIndependentOwner&&r.metadata.rejectsForeignOwnerScopes&&r.metadata.subscribedVideoCount===1&&r.output?.presentedFrameCallbacks>0&&r.output.numberedFrameObserved===true&&r.output.videoAttachmentRevision>0&&r.metadata.publicationObservationRevision>0)
 const initial=proofs.find(r=>r.metadata.descriptor?.requested_profile_id==='P1080_60');assert.ok(initial,'Initial applied profile missing')
 const compatible=proofs.find(r=>r.metadata.descriptor?.requested_profile_id==='P1080_60'&&r.metadata.descriptor.mode==='text'&&r.metadata.descriptor.publication_generation===initial.metadata.descriptor.publication_generation&&r.metadata.descriptor.operation_revision>initial.metadata.descriptor.operation_revision&&r.metadata.descriptor.profile_revision>initial.metadata.descriptor.profile_revision&&r.output.videoAttachmentRevision===initial.output.videoAttachmentRevision);assert.ok(compatible,'Compatible mode lacks fresh revision on existing publication')
 const changed=(row,previous)=>row.metadata.descriptor.publication_generation>previous.metadata.descriptor.publication_generation&&row.metadata.publicationObservationRevision>previous.metadata.publicationObservationRevision&&row.output.videoAttachmentRevision>previous.output.videoAttachmentRevision
 const low=proofs.find(r=>r.metadata.descriptor?.requested_profile_id==='P720_30'&&changed(r,compatible)&&r.metadata.descriptor.layers?.some(l=>l.width<=1280&&l.height<=720&&l.max_fps===30));assert.ok(low,'Lower applied capture lacks owned restart and confirmed encoding limits')
 const restart=proofs.find(r=>r.metadata.descriptor?.requested_profile_id==='P1080_60'&&changed(r,low));assert.ok(restart,'Higher restart reused old publication/decoded output')
 const rejoin=proofs.find(r=>r.metadata.descriptor?.requested_profile_id==='P1080_60'&&changed(r,restart));assert.ok(rejoin,'Lease rejoin reused old publication/decoded output')
 return true
}

export function requireFaultVideoProgress(rows){
 assert.ok(rows.length>=2,'Decoded fault progress unavailable')
 for(let i=0;i<rows.length;i++)assert.ok(Number.isFinite(rows[i].callbacks)&&rows[i].callbacks>=0&&(i===0||rows[i].callbacks>rows[i-1].callbacks),'Decoded callbacks froze or became unknown during sampled fault intervals')
 return true
}
