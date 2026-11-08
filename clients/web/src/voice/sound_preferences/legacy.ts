import { ref } from 'vue'
import { browserStorage, type Storage } from './safety'

// Unowned v1 device flags never become another account's server preferences.
// Keep local playback quiet until that account explicitly chooses its policy.
export class LegacySoundReview {
  readonly blocked = ref(true)
  readonly failed = ref(false)
  private account: string | null = null
  constructor(private readonly storage: Storage | null = browserStorage()) {}
  select(account: string | null): void {
    this.account = account; this.failed.value = false; this.blocked.value = true
    if (!account) return
    try {
      this.blocked.value = this.storage?.getItem(`voice-sound-legacy-reviewed:v1:${account}`) !== 'yes' &&
        ['voice-screen-start-sound:v1','voice-room-event-sounds:v1'].some(key => this.storage?.getItem(key) === 'off')
    } catch { this.failed.value = true }
  }
  acknowledge(): void {
    if (!this.account) return
    try { this.storage?.setItem(`voice-sound-legacy-reviewed:v1:${this.account}`, 'yes'); this.blocked.value = false }
    catch { this.failed.value = true }
  }
}
