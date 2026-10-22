import { describe, expect, it } from 'vitest'
import { parseSupportContact, supportPresentation } from './contact'
const peer = '22222222-2222-4222-8222-222222222222'
describe('server-confirmed support presentation', () => {
 it('aliases only the configured peer, never a matching display name', () => {
  const contact = parseSupportContact({ state: 'available', account_id: peer, revision: 4 })
  expect(supportPresentation({otherParticipantId:peer,otherParticipantDisplayName:'Оператор'}, contact)).toBe('Поддержка')
  expect(supportPresentation({otherParticipantId:'other',otherParticipantDisplayName:'Другой'}, contact)).toBe('Другой')
 })
 it('fails closed for malformed, absent, blocked and self contacts', () => {
  for (const value of [undefined, {}, {state:'available',account_id:'Поддержка',revision:1}, {state:'self',account_id:peer,revision:1}, {state:'unavailable',account_id:peer,revision:1}]) {
   expect(parseSupportContact(value).accountId).toBeUndefined()
  }
 })
})
