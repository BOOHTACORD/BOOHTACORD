import {describe,it,expect} from 'vitest'
import {parseSupportContact,isSupportPeer,supportPrivacyNotice} from './contact'
const peer='22222222-2222-4222-8222-222222222222'
describe('public product support consent',()=>{
 it('requires consent unless the server confirms the current notice',()=>{
  const contact=parseSupportContact({state:'available',revision:2,account_id:peer,mode:'product',notice_version:1,repository_public:true,consent_required:true})
  expect(contact.consentRequired).toBe(true);expect(contact.mode).toBe('product')
  expect(supportPrivacyNotice(contact)).toContain('доступны всем')
  expect(parseSupportContact({...{state:'available',revision:2,account_id:peer,mode:'product'},notice_version:0,consent_required:false}).consentRequired).toBe(true)
 })
 it('keeps the publication notice on a previously known support peer during an outage',()=>{
  const contact=parseSupportContact({state:'unavailable',revision:2,account_id:peer,mode:'product',notice_version:1,repository_public:true,consent_required:true})
  expect(isSupportPeer(peer,contact)).toBe(true)
  expect(supportPrivacyNotice(contact)).toContain('GitHub')
 })
 it('keeps old product history marked public after a local override',()=>{
  const contact=parseSupportContact({state:'available',revision:3,account_id:'33333333-3333-4333-8333-333333333333',product_account_id:peer,mode:'local',notice_version:1,repository_public:true,consent_required:false})
  expect(isSupportPeer(peer,contact)).toBe(true);expect(supportPrivacyNotice(contact,peer)).toContain('доступны всем')
 })
})
