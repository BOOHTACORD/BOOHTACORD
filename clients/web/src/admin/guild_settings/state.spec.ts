import { describe,it,expect,vi } from 'vitest'
import { createGuildSettingsState } from './state'
import { GuildSettingsError } from './client'
const initial={name:'Первая',revision:1,welcomeChannelId:null}
describe('admin guild settings',()=>{
 it('preserves the draft on conflict, refreshes revision, requires explicit retry',async()=>{
  const read=vi.fn().mockResolvedValueOnce(initial).mockResolvedValueOnce({...initial,name:'Чужая',revision:2})
  const write=vi.fn().mockRejectedValueOnce(new GuildSettingsError(409)).mockResolvedValueOnce({...initial,name:'Моя',revision:3})
  const state=createGuildSettingsState(read,write);await state.load();state.name.value='Моя'
  await state.save([]);expect(state.name.value).toBe('Моя');expect(state.revision.value).toBe(2);expect(write).toHaveBeenCalledTimes(1)
  await state.save([]);expect(write.mock.calls[1][0].expected_revision).toBe(2)
 })
 it('rejects an unavailable welcome channel without sending a mutation',async()=>{
  const write=vi.fn();const state=createGuildSettingsState(async()=>initial,write);await state.load();state.welcome.value='gone'
  await state.save([]);expect(write).not.toHaveBeenCalled();expect(state.error.value).toContain('канал')
 })
 it('drops responses after dispose',async()=>{
  let done!:(value:typeof initial)=>void
  const state=createGuildSettingsState(()=>new Promise(resolve=>{done=resolve}),vi.fn());const pending=state.load();state.dispose();done(initial);await pending
  expect(state.revision.value).toBe(0)
 })
})

describe('guild explicit edit state',()=>{
 it('has no dirty state until a value changes and cancellation does not write',async()=>{
  const write=vi.fn();const state=createGuildSettingsState(async()=>initial,write);await state.load()
  expect(state.dirty.value).toBe(false);state.name.value='Черновик';expect(state.dirty.value).toBe(true)
  state.cancel();expect(state.name.value).toBe(initial.name);expect(state.dirty.value).toBe(false);expect(write).not.toHaveBeenCalled()
 })
 it('cancel after conflict restores the freshly read server state, never the stale baseline',async()=>{
  const read=vi.fn().mockResolvedValueOnce(initial).mockResolvedValueOnce({...initial,name:'Чужая',revision:2})
  const state=createGuildSettingsState(read,vi.fn().mockRejectedValue(new GuildSettingsError(409)))
  await state.load();state.name.value='Моя';await state.save([]);expect(state.name.value).toBe('Моя')
  state.cancel();expect(state.name.value).toBe('Чужая');expect(state.revision.value).toBe(2);expect(state.dirty.value).toBe(false)
 })
 it('does not discard a pending write and acknowledges only its returned values',async()=>{
  let done!:(value:typeof initial)=>void
  const state=createGuildSettingsState(async()=>initial,()=>new Promise(resolve=>{done=resolve}))
  await state.load();state.name.value='Моя';const pending=state.save([]);state.cancel();expect(state.name.value).toBe('Моя');expect(state.busy.value).toBe(true)
  done({...initial,name:'Моя',revision:2});await pending;expect(state.dirty.value).toBe(false);expect(state.saved.value).toBe(true)
 })
})
