import { describe, expect, it, vi } from 'vitest'
import { ref } from 'vue'

import { createScreenViewerControls } from './screen_viewer_controls'
import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'

function stream(id: string): ScreenViewerStream {
  return {
    id, participantId: id, participantName: id, hasAudio: true,
    audio: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
    video: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

describe('selected screen sound', () => {
  it('mutes the selected stream and retains mute across switching', () => {
    const first = stream('alice')
    const second = stream('bob')
    const firstOutput = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const secondOutput = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const outputs = [firstOutput, secondOutput]
    const attachOutput = vi.fn(() => outputs.shift()!)
    const controller = new ScreenViewerController(() => [first, second], { attach: attachOutput } as never)
    const audio = {} as HTMLAudioElement

    controller.select('alice', {} as HTMLVideoElement, audio)
    controller.setAudioMuted(true)
    controller.select('bob', {} as HTMLVideoElement, audio)
    controller.setAudioMuted(false)

    expect(firstOutput.setMuted).toHaveBeenLastCalledWith(false)
    expect(firstOutput.dispose).not.toHaveBeenCalled()
    expect(attachOutput).toHaveBeenCalledOnce()
    expect(secondOutput.setMuted).not.toHaveBeenCalled()
    expect(controller.audioMuted).toBe(false)
    expect(first.audio!.setSubscribed).toHaveBeenLastCalledWith(false)
  })

  it('restores a zero-volume stream when the viewer asks to turn sound on', () => {
    const controller = new ScreenViewerController(() => [stream('alice')])
    const controls = createScreenViewerControls(
      { screenViewer: () => controller }, ref([]), ref<string | null>(null), ref<string | null>(null), ref(false),
    )
    const setVolume = vi.fn()
    controls.start()
    controls.select('alice', null, null)

    controls.toggleAudio(100, setVolume)
    expect(controls.audioMuted.value).toBe(true)
    controls.toggleAudio(0, setVolume)

    expect(setVolume).toHaveBeenCalledWith(100)
    expect(controls.audioMuted.value).toBe(false)
  })

  it('attaches screen audio published after the viewer selected video', () => {
    let selected: ScreenViewerStream = { ...stream('alice'), audio: undefined, hasAudio: false }
    const output = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const attach = vi.fn(() => output)
    const controller = new ScreenViewerController(() => [selected], { attach } as never)
    const audio = {} as HTMLAudioElement
    controller.select('alice', {} as HTMLVideoElement, audio)
    controller.setAudioMuted(true)
    const published = stream('alice')
    published.video = selected.video
    selected = published

    controller.reconcile()

    expect(attach).toHaveBeenCalledWith(audio)
    expect(published.audio!.setSubscribed).toHaveBeenCalledWith(true)
    expect(published.audio!.track!.attach).toHaveBeenCalledWith(audio)
    expect(output.setMuted).toHaveBeenCalledWith(true)
  })

  it('detaches the old audio track when LiveKit replaces a subscribed track on reconnect', () => {
    const selected = stream('alice')
    const controller = new ScreenViewerController(() => [selected], {
      attach: vi.fn(() => ({ dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() })),
    } as never)
    const audio = {} as HTMLAudioElement
    controller.select('alice', {} as HTMLVideoElement, audio)
    controller.setAudioMuted(true)
    const oldTrack = selected.audio!.track!
    const nextTrack = { attach: vi.fn(), detach: vi.fn() }
    const oldVideoTrack = selected.video.track!
    const nextVideoTrack = { attach: vi.fn(), detach: vi.fn() }
    selected.audio!.track = nextTrack
    selected.video.track = nextVideoTrack

    controller.reconcile()

    expect(oldTrack.detach).toHaveBeenCalledWith(audio)
    expect(nextTrack.attach).toHaveBeenCalledWith(audio)
    expect(oldVideoTrack.detach).toHaveBeenCalledOnce()
    expect(nextVideoTrack.attach).toHaveBeenCalledOnce()
    expect(controller.audioMuted).toBe(true)
  })
})
