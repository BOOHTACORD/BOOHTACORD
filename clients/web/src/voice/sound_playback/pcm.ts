import type { SoundKind } from './queue'
// Original BOOHTACORD cues, CC0. Identical synthesis in Flutter sound_playback/pcm.dart.
export function defaultSound(kind: SoundKind): Uint8Array {
  const notes = { joined: [660, 880], left: [660, 440], started: [440, 660, 880], stopped: [880, 660, 440] }[kind]
  const rate = 24000, length = notes.length * 2400
  const bytes = new Uint8Array(44 + length * 2), view = new DataView(bytes.buffer)
  const text = (offset: number, s: string) => [...s].forEach((c, i) => view.setUint8(offset + i, c.charCodeAt(0)))
  text(0, 'RIFF'); view.setUint32(4, bytes.length - 8, true); text(8, 'WAVEfmt '); view.setUint32(16, 16, true)
  view.setUint16(20, 1, true); view.setUint16(22, 1, true); view.setUint32(24, rate, true); view.setUint32(28, rate * 2, true); view.setUint16(32, 2, true); view.setUint16(34, 16, true); text(36, 'data'); view.setUint32(40, length * 2, true)
  for (let i = 0; i < length; i++) {
    const n = i % 2400, envelope = Math.min(n / 240, (2400 - n) / 480, 1)
    const sample = 6000 * envelope * Math.sin(2 * Math.PI * notes[Math.floor(i / 2400)] * n / rate)
    const quantized = Math.floor(sample * 1e6 + .5) / 1e6
    view.setInt16(44 + i * 2, Math.floor(quantized + .5), true)
  }
  return bytes
}
