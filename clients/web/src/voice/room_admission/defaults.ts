import { acquireVoiceLease, issueLiveKitCredential, releaseVoiceLease } from '../admission_client'
import type { VoiceAdmission } from '../voice_session_types'

export const defaultAdmission: VoiceAdmission = {
  acquire: acquireVoiceLease,
  credential: issueLiveKitCredential,
  release: releaseVoiceLease,
}
