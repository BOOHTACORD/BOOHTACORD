import { ref, shallowRef } from 'vue'
import { expect, it, vi } from 'vitest'
import { installVoiceConnectionLifecycle } from '../connection_lifecycle'
import { unknownScreenDiagnostics } from '../screen_diagnostics'
import type { ActiveVoiceSession, VoiceConnectionObserver } from '../voice_session'
import type { VoiceConnectionState } from '../connection_store'

for(const [ptt,expected] of [[true,'listener'],[false,'with-microphone']] as const) {
  it(`recovers ${ptt?'PTT':'VAD'} with ${expected} admission even when the old microphone was publishing`,()=>{
    let observer:VoiceConnectionObserver|undefined
    const session={setConnectionObserver:(value:VoiceConnectionObserver)=>{observer=value}}
    const active=shallowRef<ActiveVoiceSession|null>({channelId:'room',leaseId:'lease',microphone:'PUBLISHED',room:{} as never,screenProfile:null,pushToTalk:ptt} as ActiveVoiceSession)
    const recover=vi.fn()
    installVoiceConnectionLifecycle(session,active,ref<VoiceConnectionState>('CONNECTED'),ref(null),ref(false),ref(false),ref(false),ref(unknownScreenDiagnostics()),ref(null),ref('IDLE'),{stop:vi.fn()},{stop:vi.fn()},vi.fn(),undefined,recover)
    observer!.disconnected!(3)
    expect(recover).toHaveBeenCalledWith(expect.objectContaining({joinMode:expected}))
    expect(active.value).toBeNull()
  })
}
