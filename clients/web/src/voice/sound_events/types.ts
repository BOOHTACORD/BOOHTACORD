export type VoiceSoundType = 'voice.member_joined' | 'voice.member_left' | 'voice.stream_started' | 'voice.stream_stopped'
export type VoiceSoundEvent = { id: string; type: VoiceSoundType; actor: string; session: string; channel: string; time: number }
export type VoiceMember = { actor: string; lease: string }
export type VoiceStream = { actor: string; session: string }
