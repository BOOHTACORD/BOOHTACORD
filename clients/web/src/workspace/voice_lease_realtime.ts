import type { VoiceLeaseRevocationReason } from '../voice/voice_lease_revocation_reason'

interface VoiceLeaseControl {
  active: { leaseId: string } | null
  state?: string
  revokeLease(leaseID: string, reason: VoiceLeaseRevocationReason): Promise<boolean>
}
interface VoiceNavigation { clearActiveVoice(): void }
type AfkMove = (channelID: string) => Promise<void>

export async function applyVoiceLeaseRevocation(voice: VoiceLeaseControl, navigation: VoiceNavigation, leaseID: string, reason: VoiceLeaseRevocationReason, targetChannelID?: string, moveToAfk?: AfkMove): Promise<void> {
  const activeMatch = voice.active?.leaseId === leaseID
  if (!activeMatch && voice.state !== 'JOINING') return
  if (await voice.revokeLease(leaseID, reason) && activeMatch) {
    navigation.clearActiveVoice()
    if (reason === 'AFK_MOVE' && targetChannelID) await moveToAfk?.(targetChannelID)
  }
}
