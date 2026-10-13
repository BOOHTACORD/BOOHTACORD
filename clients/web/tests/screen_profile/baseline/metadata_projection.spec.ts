import {readFileSync} from 'node:fs'
import {expect,it,vi} from 'vitest'
import {ScreenBaselineSession} from './session'
import {parseScreenDescriptor} from '../../../src/voice/screen_profile_metadata/descriptor'
const fixture=JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.fixtures.json',import.meta.url),'utf8')).validDescriptor
it('QA metadata reads current production parser with independent owners and never exposes identity or adds subscriptions',()=>{
 vi.stubGlobal('document',{addEventListener:vi.fn(),createElement:vi.fn(()=>({}))})
 const owner={originId:'https://owned.invalid',accountId:'synthetic-account',roomId:'synthetic-room'}
 const raw=structuredClone(fixture);raw.scope={...raw.scope,origin_id:owner.originId,account_id:owner.accountId,room_id:owner.roomId}
 const session=new ScreenBaselineSession()
 ;(session as any).room={remoteParticipants:new Map([['synthetic-lease',{metadata:'account:'+owner.accountId,attributes:{'boohtacord.screen-share.v1':JSON.stringify(raw)},videoTrackPublications:new Map([['owned',{isSubscribed:true}]])}]])}
 const result=session.metadataSnapshot(owner,parseScreenDescriptor)
 expect(result.descriptorValidForIndependentOwner).toBe(true)
 expect(result.rejectsForeignOwnerScopes).toBe(true)
 expect(result.subscribedVideoCount).toBe(1)
 expect(JSON.stringify(result)).not.toContain(owner.accountId)
 expect(JSON.stringify(result)).not.toContain(owner.roomId)
 expect(result.descriptor?.requested_profile_id).toBe('P1080_60')
 expect(session.metadataSnapshot({...owner,originId:'https://foreign.invalid'},parseScreenDescriptor).descriptorValidForIndependentOwner).toBe(false)
 vi.unstubAllGlobals()
})

it('publication SID is compared privately so republish evidence exposes only a monotonic observation revision',()=>{
 vi.stubGlobal('document',{addEventListener:vi.fn(),createElement:vi.fn(()=>({}))})
 const owner={originId:'https://owned.invalid',accountId:'synthetic-account',roomId:'synthetic-room'}
 const raw=structuredClone(fixture);raw.scope={...raw.scope,origin_id:owner.originId,account_id:owner.accountId,room_id:owner.roomId}
 const publication={isSubscribed:true,trackSid:'private-first-publication'};const session=new ScreenBaselineSession()
 ;(session as any).room={remoteParticipants:new Map([['private-participant',{metadata:'account:'+owner.accountId,attributes:{'boohtacord.screen-share.v1':JSON.stringify(raw)},videoTrackPublications:new Map([['only',publication]])}]])}
 expect(session.metadataSnapshot(owner,parseScreenDescriptor)).toMatchObject({publicationObservationRevision:1,publicationSidChanged:false})
 publication.trackSid='private-replacement-publication';const next=session.metadataSnapshot(owner,parseScreenDescriptor)
 expect(next).toMatchObject({publicationObservationRevision:2,publicationSidChanged:true});expect(JSON.stringify(next)).not.toContain('private-');vi.unstubAllGlobals()
})
