import { describe, expect, it, vi } from 'vitest'
import { VoiceSoundPolicy, type VoiceSoundEvent } from './policy'

const event = (id: string, type: VoiceSoundEvent['type'], actor = 'other', session = 'lease-1', time = 10000): VoiceSoundEvent => ({ id, type, actor, session, channel: 'room', time })

describe('confirmed voice sound policy', () => {
  it('seeds silently, ignores self, foreign room, duplicates and stale events', () => {
    const play = vi.fn(); const policy = new VoiceSoundPolicy('room', 'self', play)
    policy.seed([{ actor: 'existing', lease: 'l1' }], [])
    policy.accept(event('old', 'voice.member_joined', 'existing', 'l1'), 10000)
    policy.accept(event('self', 'voice.member_joined', 'self'), 10000)
    policy.accept({ ...event('foreign', 'voice.member_joined'), channel: 'elsewhere' }, 10000)
    policy.accept(event('late', 'voice.member_joined', 'other', 'lease-1', 1000), 10000)
    policy.accept(event('join', 'voice.member_joined'), 10000)
    policy.accept(event('join', 'voice.member_joined'), 10000)
    expect(play.mock.calls.map(([e]) => e.type)).toEqual(['voice.member_joined'])
  })

  it('suppresses short lease reconnects and stream stop when author leaves', () => {
    const play = vi.fn(); const policy = new VoiceSoundPolicy('room', 'self', play)
    policy.seed([{ actor: 'other', lease: 'lease-1' }], [{ actor: 'other', session: 'stream-1' }])
    policy.accept(event('l1', 'voice.member_left'), 10000)
    policy.accept(event('j1', 'voice.member_joined', 'other', 'lease-1', 10500), 10500)
    policy.flush(12000); expect(play).not.toHaveBeenCalled()
    policy.accept(event('s1', 'voice.stream_stopped', 'other', 'stream-1', 13000), 13000)
    policy.accept(event('l2', 'voice.member_left', 'other', 'lease-1', 13100), 13100)
    policy.flush(15000)
    expect(play.mock.calls.map(([e]) => e.type)).toEqual(['voice.member_left'])
  })

  it('drops reconnect history and limits bursts without queuing delayed sound', () => {
    const play = vi.fn(); const policy = new VoiceSoundPolicy('room', 'self', play)
    policy.seed([], []); policy.pause()
    policy.accept(event('ignored', 'voice.member_joined'), 10000)
    policy.seed([], [])
    for (let i = 0; i < 5; i++) policy.accept(event(`j${i}`, 'voice.member_joined', `u${i}`, `l${i}`, 11000), 11000)
    policy.flush(17000)
    expect(play).toHaveBeenCalledTimes(3)
  })
})

it('never plays old delayed events and retains burst protection over reconnect', () => {
  const play = vi.fn(); const policy = new VoiceSoundPolicy('room', 'self', play)
  policy.seed([{ actor: 'old', lease: 'lease-old' }], [])
  policy.accept(event('leave-old', 'voice.member_left', 'old', 'lease-old'), 10000)
  policy.flush(20000)
  expect(play).not.toHaveBeenCalled()
  for (let i = 0; i < 3; i++) policy.accept(event(`join-${i}`, 'voice.member_joined', `user-${i}`, `lease-${i}`, 21000), 21000)
  policy.pause(); policy.seed([], [])
  policy.accept(event('another', 'voice.member_joined', 'user-new', 'lease-new', 21500), 21500)
  expect(play).toHaveBeenCalledTimes(3)
})

it('treats replacement tracks as one stream session and plays a real stop once', () => {
  const play = vi.fn(); const policy = new VoiceSoundPolicy('room', 'self', play)
  policy.seed([{ actor: 'other', lease: 'lease-1' }], [])
  policy.accept(event('start-1', 'voice.stream_started', 'other', 'stream-1'), 10000)
  policy.accept(event('stop-temp', 'voice.stream_stopped', 'other', 'stream-1', 10500), 10500)
  policy.accept(event('replacement', 'voice.stream_started', 'other', 'stream-1', 11000), 11000)
  policy.flush(12500)
  policy.accept(event('stop-final', 'voice.stream_stopped', 'other', 'stream-1', 13000), 13000)
  policy.flush(14500)
  expect(play.mock.calls.map(([e]) => e.type)).toEqual(['voice.stream_started', 'voice.stream_stopped'])
})

it('does not play a due stop when the same event batch reports the owner leaving', () => {
  const play = vi.fn(); const policy = new VoiceSoundPolicy('room', 'self', play)
  policy.seed([{ actor: 'other', lease: 'lease-1' }], [{ actor: 'other', session: 'stream-1' }])
  policy.accept(event('stop', 'voice.stream_stopped', 'other', 'stream-1'), 10000)
  policy.accept(event('left', 'voice.member_left', 'other', 'lease-1', 11200), 11200)
  policy.flush(13000)
  expect(play.mock.calls.map(([e]) => e.type)).toEqual(['voice.member_left'])
})
