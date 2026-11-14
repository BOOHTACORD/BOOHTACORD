import { describe, expect, it, vi } from 'vitest'

import { ScreenViewerMediaBinding } from './screen_viewer_media_binding'
import type { ScreenViewerStream, ScreenViewerTrack } from './screen_viewer_types'

function mediaTrack(): ScreenViewerTrack {
  return { attach: vi.fn(), detach: vi.fn() }
}

describe('screen viewer media binding', () => {
  it('keeps selected stream audio unmuted when participant voices are deafened', () => {
    const output = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const mixer = { attach: vi.fn(() => output) }
    const audioTrack = mediaTrack()
    const videoTrack = mediaTrack()
    const stream = {
      audio: { track: audioTrack },
      hasAudio: true,
      id: 'stream-1',
      isLocal: false,
      participantId: 'participant-1',
      participantName: 'Alice',
      video: { track: videoTrack },
    } as unknown as ScreenViewerStream
    const binding = new ScreenViewerMediaBinding(mixer)

    binding.bind(stream, {} as HTMLVideoElement, {} as HTMLAudioElement, false, 125)
    binding.setAudioState(false, 125)

    expect(mixer.attach).toHaveBeenCalledOnce()
    expect(output.setMuted).toHaveBeenLastCalledWith(false)
    expect(output.setVolume).toHaveBeenLastCalledWith(125)
  })
})
