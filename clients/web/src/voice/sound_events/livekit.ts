import { RoomEvent, Track, type Room, type RemoteParticipant, type RemoteTrackPublication } from 'livekit-client'
import { accountIdFromMetadata } from '../participant_identity'
import { VoiceSoundPolicy, type VoiceSoundEvent } from './policy'
import { soundQueue, voiceSoundPreferences } from '../sound_playback/runtime'

export function bindVoiceSounds(room: Room) {
  let policy: VoiceSoundPolicy | null = null, timer: ReturnType<typeof setInterval> | null = null
  let sequence = 0
  const custom = new Map<string, string>()
  const actor = (p: RemoteParticipant) => accountIdFromMetadata(p.metadata)
  const emit = (e: VoiceSoundEvent) => soundQueue.submit({ type: ({ 'voice.member_joined':'joined', 'voice.member_left':'left', 'voice.stream_started':'started', 'voice.stream_stopped':'stopped' } as const)[e.type],
    ...(e.type === 'voice.member_joined' && voiceSoundPreferences.settings.value.allow_custom ? { customId: custom.get(e.actor) } : {}) })
  const accept = (p: RemoteParticipant, type: VoiceSoundEvent['type'], session: string) => {
    const account = actor(p); if (!account || !policy) return
    const id = p.attributes?.['boohtacord.join_sound_id']
    if (id) custom.set(account, id); else custom.delete(account)
    const time = Date.now()
    policy.accept({ actor: account, type, channel: room.name, session, time, id: `${++sequence}` }, time)
  }
  const pause = () => { policy?.pause(); policy = null; custom.clear(); soundQueue.clear(); if (timer) clearInterval(timer); timer = null }
  const seed = () => {
    pause(); policy = new VoiceSoundPolicy(room.name, accountIdFromMetadata(room.localParticipant.metadata) ?? '', emit)
    const participants = [...room.remoteParticipants.values()].filter(p => actor(p))
    policy.seed(participants.map(p => ({ actor: actor(p)!, lease: p.identity })), participants.flatMap(p => [...p.trackPublications.values()].filter(t => t.source === Track.Source.ScreenShare).map(t => ({ actor: actor(p)!, session: t.trackSid }))))
    timer = setInterval(() => policy?.flush(Date.now()), 100)
  }
  room.on(RoomEvent.ParticipantConnected, p => accept(p, 'voice.member_joined', p.identity))
  room.on(RoomEvent.ParticipantDisconnected, p => accept(p, 'voice.member_left', p.identity))
  const track = (type: VoiceSoundEvent['type']) => (t: RemoteTrackPublication, p: RemoteParticipant) => { if (t.source === Track.Source.ScreenShare) accept(p, type, t.trackSid) }
  room.on(RoomEvent.TrackPublished, track('voice.stream_started')); room.on(RoomEvent.TrackUnpublished, track('voice.stream_stopped'))
  room.on(RoomEvent.Reconnecting, pause); room.on(RoomEvent.SignalReconnecting, pause); room.on(RoomEvent.Reconnected, seed); room.on(RoomEvent.Disconnected, pause)
  return { seed, pause }
}
