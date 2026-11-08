import { ref, watch } from 'vue'
import { VoiceSoundPreferences } from '../sound_preferences/state'
import { BrowserSoundPlayer } from './browser'
import { SoundPlaybackQueue, type SoundKind } from './queue'
import { loadJoinSound } from './custom_loader'
import { LegacySoundReview } from '../sound_preferences/legacy'

export const voiceSoundPreferences = new VoiceSoundPreferences()
export const legacySoundReview = new LegacySoundReview()
export const soundOutput = ref('default'), soundsDeafened = ref(false)
const player = new BrowserSoundPlayer(() => voiceSoundPreferences.settings.value.volume, () => soundOutput.value)
export const soundQueue = new SoundPlaybackQueue({ load: loadJoinSound, play: (kind, bytes, signal) => player.play(kind, bytes, signal) },
  kind => !legacySoundReview.blocked.value && !soundsDeafened.value && voiceSoundPreferences.settings.value.enabled && voiceSoundPreferences.settings.value[kind])
watch([voiceSoundPreferences.settings, soundsDeafened, soundOutput], () => soundQueue.clear(), { flush: 'sync' })
export function previewSound(kind: SoundKind) { soundQueue.submit({ type: kind }) }
