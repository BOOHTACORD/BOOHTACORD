import type { VoiceRoomEventSound } from './stream_start_chime'

export class VoiceParticipantSoundTracker {
  private readonly participants = new Set<string>()
  private active = false

  constructor(private readonly play: (event: VoiceRoomEventSound) => void) {}

  seed(identities: Iterable<string>): void {
    this.participants.clear()
    for (const identity of identities) {
      if (isHumanVoiceParticipant(identity)) this.participants.add(identity)
    }
    this.active = true
  }

  pause(): void {
    this.active = false
  }

  reset(): void {
    this.active = false
    this.participants.clear()
  }

  participantConnected(identity: string): void {
    if (!this.active || !isHumanVoiceParticipant(identity) || this.participants.has(identity)) return
    this.participants.add(identity)
    this.play('participant-joined')
  }

  participantDisconnected(identity: string): void {
    if (!this.active || !isHumanVoiceParticipant(identity) || !this.participants.delete(identity)) return
    this.play('participant-left')
  }
}

function isHumanVoiceParticipant(identity: string): boolean {
  return identity.length > 0 && !identity.startsWith('voice-lease:')
}
