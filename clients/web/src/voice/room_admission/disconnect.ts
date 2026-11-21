import type { VoiceRoom } from '../livekit_gateway'

const cleanupTimeoutMs = 2_000

// Preserve the join failure even if SDK teardown rejects or never settles.
export async function disconnectFailedRoom(room: VoiceRoom): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    await Promise.race([
      Promise.resolve().then(() => room.disconnect()),
      new Promise<void>(resolve => { timer = setTimeout(resolve, cleanupTimeoutMs) }),
    ])
  } catch {
    // Lease cleanup still has to run; the caller retains the original error.
  } finally {
    if (timer !== undefined) clearTimeout(timer)
  }
}
