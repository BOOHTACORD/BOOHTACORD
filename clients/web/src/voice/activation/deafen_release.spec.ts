import { ref, shallowRef } from 'vue'
import { expect, it, vi } from 'vitest'
import { VoiceSession, type VoiceAdmission } from '../voice_session'
import { createMicrophoneControls } from '../microphone_controls'
import { createDeafenControls } from '../deafen_controls'

async function setup() {
  let enabled = true
  const publish = vi.fn(async (value: boolean) => { enabled = value })
  const room = { on: vi.fn(), disconnect: vi.fn(), setDeafened: vi.fn(), setMicrophone: publish }
  const admission: VoiceAdmission = {
    acquire: vi.fn(async () => ({ id:'lease', channelId:'room', transferred:false })),
    credential: vi.fn(async () => ({ url:'wss://owned.test', token:'synthetic', expiresAt:'2030-01-01T00:00:00Z' })),
    release: vi.fn(),
  }
  const session = new VoiceSession(admission, async () => ({ room:room as never, microphone:'PUBLISHED' }))
  await session.join('room')
  const deafened=ref(false), muted=ref(false), denied=ref(false), error=ref<string|null>(null)
  const mic=createMicrophoneControls(session,shallowRef(session.active),ref('CONNECTED'),deafened,muted,denied,error)
  const deafen=createDeafenControls(session,deafened,muted,denied,error)
  return { session, mic, deafen, muted, publish, room, enabled:()=>enabled }
}

it('PTT key release during deafen cancels microphone restoration', async () => {
  const h=await setup()
  await h.deafen.toggleDeafen()
  await h.mic.setMicrophoneMuted(true)
  h.publish.mockClear()
  await h.deafen.toggleDeafen()
  expect(h.publish).not.toHaveBeenCalledWith(true,expect.anything())
  expect(h.enabled()).toBe(false)
  expect(h.muted.value).toBe(true)
  await h.session.leave()
})

it('ordinary deafen still restores an unmuted VAD microphone', async () => {
  const h=await setup()
  await h.deafen.toggleDeafen(); await h.deafen.toggleDeafen()
  expect(h.enabled()).toBe(true)
  expect(h.muted.value).toBe(false)
  await h.session.leave()
})

it('PTT release while the deafen server update is pending cancels restoration', async () => {
  const h=await setup()
  let complete!:()=>void
  h.room.setDeafened.mockImplementationOnce(()=>new Promise<void>(resolve=>{complete=resolve}))
  const pending=h.deafen.toggleDeafen()
  await vi.waitFor(()=>expect(complete).toBeTypeOf('function'))
  await h.mic.setMicrophoneMuted(true)
  complete();await pending
  await h.deafen.toggleDeafen()
  expect(h.enabled()).toBe(false)
  expect(h.muted.value).toBe(true)
  await h.session.leave()
})
