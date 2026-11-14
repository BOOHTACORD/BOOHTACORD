export interface RemoteMicrophonePublication {
  isMuted?: boolean
}

export interface RemoteParticipantSource {
  accountId: string | null
  deafened?: boolean
  id: string
  microphone?: RemoteMicrophonePublication
  name?: string
}

export interface RemoteParticipantCard {
  accountId: string | null
  deafened: boolean
  id: string
  microphoneMuted: boolean
  name: string | undefined
  speaking: boolean
}

export interface SpeakingPlayback {
  isSpeaking(participantId: string): boolean
  onChange(listener: () => void): () => void
}

export class RemoteParticipantController {
  private current: RemoteParticipantCard[] = []
  private readonly listeners = new Set<() => void>()

  constructor(private readonly source: () => RemoteParticipantSource[], private readonly playback: SpeakingPlayback) {
    playback.onChange(() => this.refresh())
  }

  cards(): RemoteParticipantCard[] {
    return this.current
  }

  onChange(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  refresh(): void {
    this.current = this.source().map((participant) => ({
      accountId: participant.accountId,
      deafened: participant.deafened === true,
      id: participant.id,
      microphoneMuted: !participant.microphone || participant.microphone.isMuted === true,
      name: participant.name,
      speaking: this.playback.isSpeaking(participant.id),
    }))
    this.listeners.forEach((listener) => listener())
  }
}
