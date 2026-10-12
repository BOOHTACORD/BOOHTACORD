import {beforeEach,describe,expect,it} from 'vitest'
import {createPinia,setActivePinia} from 'pinia'
import {clearAuthenticatedState} from '../../identity/clear_authenticated_state'
import {useSearchSessions,type SearchSession} from './state'
const session=(query:string):SearchSession=>({query,activeQuery:query,scope:'current',authorId:'qa-author',attachment:'without',dateFrom:'2026-10-10',dateTo:'2026-10-12',submitted:true,scrollTop:180})
describe('authenticated search sessions',()=>{
 beforeEach(()=>setActivePinia(createPinia()))
 it('restores independent DM/channel origins without overwriting another conversation',()=>{
  const sessions=useSearchSessions()
  sessions.save('DIRECT_MESSAGE:b',session('Search B'))
  sessions.save('DIRECT_MESSAGE:c',session('Search C'))
  sessions.save('CHANNEL:b',session('Channel B'))
  expect(sessions.restore('DIRECT_MESSAGE:b')).toEqual(session('Search B'))
  expect(sessions.restore('DIRECT_MESSAGE:c')).toEqual(session('Search C'))
  expect(sessions.restore('CHANNEL:b')).toEqual(session('Channel B'))
  expect(sessions.restore('global')).toBeNull()
 })
 it('a later account cannot restore or resurrect an earlier account session',()=>{
  const previous=useSearchSessions()
  previous.save('DIRECT_MESSAGE:b',session('Private search'))
  clearAuthenticatedState()
  const next=useSearchSessions()
  expect(next.restore('DIRECT_MESSAGE:b')).toBeNull()
  previous.save('DIRECT_MESSAGE:b',session('Late disposed panel'))
  expect(next.restore('DIRECT_MESSAGE:b')).toBeNull()
 })
 it('editing a restored form does not mutate a saved result position before submission',()=>{
  const sessions=useSearchSessions(),original=session('Search B')
  sessions.save('DIRECT_MESSAGE:b',original)
  original.query='Caller edited';const reopened=sessions.restore('DIRECT_MESSAGE:b')!
  reopened.query='New unsubmitted query';reopened.scrollTop=0
  expect(sessions.restore('DIRECT_MESSAGE:b')).toEqual(session('Search B'))
 })
})
