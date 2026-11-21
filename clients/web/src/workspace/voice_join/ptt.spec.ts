import { expect, it, vi } from 'vitest'
import { createWorkspaceVoiceJoin } from './action'
import type { VoiceJoinMode } from '../../voice/livekit_gateway'

for (const requested of ['listener','with-microphone'] as const) {
  it(`arms PTT on an explicit ${requested} join while entering muted`, async () => {
    const activation={mode:'PTT',setMode:vi.fn()}
    const voice={active:{channelId:'room'},join:vi.fn()}
    const audio={loadInput:vi.fn(),loadProcessing:vi.fn()}
    const navigation={confirmVoiceConnected:vi.fn()}
    const join=createWorkspaceVoiceJoin(audio as never,activation as never,voice as never,navigation as never,vi.fn())
    await join('room',false,requested)
    expect(voice.join).toHaveBeenCalledExactlyOnceWith('room',false,'listener')
    expect(activation.setMode).toHaveBeenCalledExactlyOnceWith('PTT')
  })
}

it('an ordinary VAD listener join never arms PTT', async () => {
  const activation={mode:'VAD',setMode:vi.fn()}
  const voice={active:{channelId:'room'},join:vi.fn()}
  const audio={loadInput:vi.fn(),loadProcessing:vi.fn()}
  const join=createWorkspaceVoiceJoin(audio as never,activation as never,voice as never,{confirmVoiceConnected:vi.fn()} as never,vi.fn())
  await join('room',false,'listener' satisfies VoiceJoinMode)
  expect(activation.setMode).not.toHaveBeenCalled()
  expect(voice.join).toHaveBeenCalledExactlyOnceWith('room',false,'listener')
})
