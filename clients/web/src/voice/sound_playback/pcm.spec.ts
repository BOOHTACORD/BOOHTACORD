import { createHash } from 'node:crypto'
import { expect, it } from 'vitest'
import fixtures from '../../../../../contracts/voice-sound-pcm.fixtures.json'
import { defaultSound } from './pcm'
import type { SoundKind } from './queue'
it('uses the same original PCM cues as Flutter on every event', () => {
  for (const [kind,hash] of Object.entries(fixtures)) expect(createHash('sha256').update(defaultSound(kind as SoundKind)).digest('hex')).toBe(hash)
})
