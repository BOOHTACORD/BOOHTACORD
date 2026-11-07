import { expect, it, vi } from 'vitest'
import { VoiceSoundPreferences } from './state'
const settings = { enabled:true, joined:true, left:true, started:true, stopped:true, allow_custom:true, volume:50 }
const snapshot=(revision:number,change={})=>new Response(JSON.stringify({revision,settings:{...settings,...change}}))
it('rebases a conflicting field update without overwriting another device volume',async()=>{
  const request=vi.fn().mockResolvedValueOnce(snapshot(0)).mockResolvedValueOnce(new Response('',{status:409}))
    .mockResolvedValueOnce(snapshot(1,{volume:25})).mockResolvedValueOnce(snapshot(2,{volume:25,joined:false}))
  const prefs=new VoiceSoundPreferences(request)
  await prefs.select('a'); await prefs.patch({joined:false})
  expect(prefs.settings.value).toMatchObject({volume:25,joined:false})
  expect(JSON.parse(request.mock.calls[3][1].body)).toEqual({expected_revision:1,joined:false})
  expect(prefs.unsynchronised.value).toBe(false)
})
