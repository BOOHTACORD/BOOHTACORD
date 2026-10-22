import { beforeEach, expect, it } from 'vitest'
import { createSupportOpener } from './open'
import { telemetrySession } from '../telemetry/action_scope/session'
import type { SupportContact } from './contact'
const accountId='22222222-2222-4222-8222-222222222222'
beforeEach(()=>telemetrySession.reset())
it('waits for confirmed metadata when the initial navigation read was superseded',async()=>{
 let contact:SupportContact={state:'not_configured',revision:0};let reads=0
 const flow=createSupportOpener({refresh:async()=>{if(++reads>=2)contact={state:'available',revision:2,accountId}},contact:()=>contact,has:()=>true})
 const id=await flow.openSupport(async()=>new Response(JSON.stringify({id:'pair',participant_one_id:'actor',participant_two_id:accountId,created_at:'2026-10-22T00:00:00Z'})))
 expect(id).toBe('pair');expect(flow.supportNotice.value).toBeNull()
})
it('unconfigured support never creates a DM or sends a message',async()=>{
 let requests=0
 const flow=createSupportOpener({refresh:async()=>{},contact:()=>({state:'not_configured',revision:1}),has:()=>false})
 expect(await flow.openSupport(async()=>{requests++;throw Error('unexpected egress')})).toBeNull()
 expect(requests).toBe(0);expect(flow.supportNotice.value).toContain('не назначена')
})
it('opens through the ordinary pair endpoint and verifies refreshed assignment',async()=>{
 let reads=0
 const flow=createSupportOpener({refresh:async()=>{reads++},contact:()=>({state:'available',revision:2,accountId}),has:()=>true})
 expect(await flow.openSupport(async(url,init)=>{
  expect(url).toContain('/direct-messages');expect(init.method).toBe('POST');expect(JSON.parse(String(init.body))).toEqual({participant_id:accountId})
  return new Response(JSON.stringify({id:'pair',participant_one_id:'actor',participant_two_id:accountId,created_at:'2026-10-22T00:00:00Z'}),{status:200})
 })).toBe('pair')
 expect(reads).toBe(2)
})
it('changed support assignment and account boundaries reject stale navigation',async()=>{
 let contact:SupportContact={state:'available',revision:2,accountId};let release!:()=>void
 const flow=createSupportOpener({refresh:async()=>{},contact:()=>contact,has:()=>true})
 const first=flow.openSupport(async()=>{contact={state:'available',revision:3,accountId:'33333333-3333-4333-8333-333333333333'};return new Response(JSON.stringify({id:'old-pair',participant_one_id:'actor',participant_two_id:accountId,created_at:'2026-10-22T00:00:00Z'}))})
 expect(await first).toBeNull();expect(flow.supportNotice.value).toContain('изменился')
 contact={state:'available',revision:4,accountId}
 const second=flow.openSupport(async()=>{await new Promise<void>(r=>release=r);return new Response(JSON.stringify({id:'old-account-pair',participant_one_id:'actor',participant_two_id:accountId,created_at:'2026-10-22T00:00:00Z'}))})
 await Promise.resolve();telemetrySession.reset();flow.invalidate();release();expect(await second).toBeNull()
})

it.each(['installation', 'account'] as const)('discards a late result across the %s boundary',async boundary=>{
 telemetrySession.bindInstallation('11111111-1111-4111-8111-111111111111')
 telemetrySession.bind('a'.repeat(32),'1')
 let release!:()=>void
 const flow=createSupportOpener({refresh:async()=>{},contact:()=>({state:'available',revision:1,accountId}),has:()=>true})
 const pending=flow.openSupport(async()=>{await new Promise<void>(resolve=>release=resolve);return new Response(JSON.stringify({id:'old-pair',participant_one_id:'actor',participant_two_id:accountId,created_at:'2026-10-22T00:00:00Z'}))})
 await Promise.resolve()
 if(boundary==='installation')telemetrySession.bindInstallation('33333333-3333-4333-8333-333333333333')
 else telemetrySession.bind('b'.repeat(32),'1')
 release();expect(await pending).toBeNull();expect(flow.supportOpening.value).toBe(false)
})
