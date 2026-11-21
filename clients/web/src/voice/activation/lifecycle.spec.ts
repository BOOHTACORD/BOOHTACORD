import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { nextTick, reactive, ref } from 'vue'
interface Room { id:string; listenerOnly:boolean; pushToTalk?:boolean }
interface Voice { active:Room|null; state:string; microphoneMuted:boolean; microphonePermissionDenied:boolean; deafened:boolean; setMicrophoneMuted:ReturnType<typeof vi.fn> }
const dependency=vi.hoisted(()=>({voice:null as unknown as Voice}))
vi.mock('../connection_store',()=>({useVoiceConnectionStore:()=>dependency.voice}))
import { createPttActivation } from './ptt'
class Hub {
  listeners=new Map<string,Set<(e:unknown)=>void>>()
  addEventListener(name:string,fn:(e:unknown)=>void) { if(!this.listeners.has(name))this.listeners.set(name,new Set());this.listeners.get(name)!.add(fn) }
  removeEventListener(name:string,fn:(e:unknown)=>void) { this.listeners.get(name)?.delete(fn) }
  emit(name:string,repeat=false) { for(const fn of this.listeners.get(name)??[])fn({code:'KeyV',repeat,target:null,preventDefault:()=>{}}) }
}
let hub:Hub, owner:ReturnType<typeof createPttActivation>
const settle=async()=>{await nextTick();for(let i=0;i<8;i++)await Promise.resolve()}
beforeEach(async()=>{
  hub=new Hub();vi.stubGlobal('window',hub);vi.stubGlobal('document',hub)
  dependency.voice=reactive({active:{id:'old',listenerOnly:false},state:'CONNECTED',microphoneMuted:false,microphonePermissionDenied:false,deafened:false,setMicrophoneMuted:vi.fn(async(muted:boolean)=>{dependency.voice.microphoneMuted=muted})})
  owner=createPttActivation(ref('KeyV'),ref(null),ref(false));await owner.start()
})
afterEach(async()=>{await owner.stop(false);vi.unstubAllGlobals()})

it('replacement room releases the previous hold and requires a fresh press',async()=>{
  hub.emit('keydown');await settle();expect(dependency.voice.microphoneMuted).toBe(false)
  dependency.voice.active={id:'new',listenerOnly:true};dependency.voice.microphoneMuted=false
  await settle();expect(dependency.voice.microphoneMuted).toBe(true)
  hub.emit('keydown',true);await settle();expect(dependency.voice.microphoneMuted).toBe(true)
  hub.emit('keyup');hub.emit('keydown');await settle();expect(dependency.voice.microphoneMuted).toBe(false)
})

it('reconnecting releases a held key instead of resuming an open microphone',async()=>{
  hub.emit('keydown');await settle();dependency.voice.state='RECONNECTING'
  await settle();expect(dependency.voice.microphoneMuted).toBe(true)
  dependency.voice.state='CONNECTED';hub.emit('keydown',true);await settle()
  expect(dependency.voice.microphoneMuted).toBe(true)
})

it('a queued old-room press cannot unmute the replacement room',async()=>{
  dependency.voice.setMicrophoneMuted.mockClear();hub.emit('keydown')
  dependency.voice.active={id:'new',listenerOnly:true};dependency.voice.microphoneMuted=true
  await settle()
  expect(dependency.voice.setMicrophoneMuted).not.toHaveBeenCalledWith(false)
  expect(dependency.voice.microphoneMuted).toBe(true)
})
