import { afterEach, describe, expect, it, vi } from 'vitest'

import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'

function stream(id: string, hasAudio = true, calls: string[] = []): ScreenViewerStream {
  return {
    hasAudio,
    id,
    participantId: id,
    participantName: id.toUpperCase(),
    audio: hasAudio ? { setSubscribed: vi.fn((subscribed: boolean) => calls.push(`${id}:audio:${subscribed}`)), track: { attach: vi.fn(), detach: vi.fn() } } : undefined,
    video: { setSubscribed: vi.fn((subscribed: boolean) => calls.push(`${id}:video:${subscribed}`)), track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

afterEach(() => { vi.unstubAllGlobals() })

describe('screen viewer controller', () => {
  it('detaches and unsubscribes the old screen before subscribing to the selected one', () => {
    const calls: string[] = []
    const old = stream('alice', true, calls)
    const next = stream('bob', true, calls)
    const controller = new ScreenViewerController(() => [old, next])
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controller.select('alice', video, audio)
    vi.clearAllMocks()
    calls.splice(0)
    controller.select('bob', video, audio)

    expect(old.video.track!.detach).toHaveBeenCalledWith(video)
    expect(old.audio!.track!.detach).toHaveBeenCalledWith(audio)
    expect(old.video.setSubscribed).toHaveBeenCalledWith(false)
    expect(old.audio!.setSubscribed).toHaveBeenCalledWith(false)
    expect(next.video.setSubscribed).toHaveBeenCalledWith(true)
    expect(next.audio!.setSubscribed).toHaveBeenCalledWith(true)
    expect(calls.indexOf('alice:video:false')).toBeLessThan(calls.indexOf('bob:video:true'))
    expect(calls.indexOf('alice:audio:false')).toBeLessThan(calls.indexOf('bob:audio:true'))
    expect(controller.selectedId).toBe('bob')
  })

  it('keeps the last preview thumbnail when the viewer returns to participant cards', () => {
    const objectUrls = { createObjectURL: vi.fn(() => 'blob:alice-preview'), revokeObjectURL: vi.fn() }
    vi.stubGlobal('URL', objectUrls)
    const selected = stream('alice')
    const controller = new ScreenViewerController(() => [selected])
    const thumbnail = new Uint8Array([0xff, 0xd8, 0xff, 0xd9])

    controller.setThumbnail('alice', thumbnail)
    controller.select('alice', {} as HTMLVideoElement, {} as HTMLAudioElement)
    controller.clear()

    expect(controller.selectedId).toBeNull()
    expect(controller.cards()[0]?.thumbnailUrl).toBe('blob:alice-preview')
    expect(objectUrls.revokeObjectURL).not.toHaveBeenCalled()

    controller.stop()
    expect(objectUrls.revokeObjectURL).toHaveBeenCalledWith('blob:alice-preview')
  })

  it('clears the selection when the selected remote stream disappears', () => {
    const selected = stream('alice')
    const remaining = stream('bob')
    const streams: ScreenViewerStream[] = [selected, remaining]
    const controller = new ScreenViewerController(() => streams)
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controller.select('alice', video, audio)
    streams.splice(0, 1)
    controller.reconcile()

    expect(controller.selectedId).toBeNull()
    expect(controller.ended).toBe(true)
    expect(remaining.video.setSubscribed).not.toHaveBeenCalled()
    expect(selected.video.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(selected.audio!.setSubscribed).toHaveBeenLastCalledWith(false)
    controller.clear()
    expect(controller.ended).toBe(false)
  })

  it('requires a new selection when the selected publication disappears', () => {
    const initial = stream('alice-old')
    const streams: ScreenViewerStream[] = [initial]
    const controller = new ScreenViewerController(() => streams)
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement
    controller.select(initial.id, video, audio)

    streams.splice(0)
    controller.reconcile()
    const restarted = stream('alice-new')
    restarted.participantId = initial.participantId
    streams.push(restarted)
    controller.reconcile()

    expect(controller.selectedId).toBeNull()
    expect(controller.ended).toBe(true)
    expect(restarted.video.setSubscribed).not.toHaveBeenCalledWith(true)
    controller.select(restarted.id, video, audio)
    expect(controller.selectedId).toBe(restarted.id)
    expect(controller.ended).toBe(false)
  })

  it('rejects a stream not reported by the current room', () => {
    const controller = new ScreenViewerController(() => [])

    expect(() => controller.select('not-in-room', {} as HTMLVideoElement, {} as HTMLAudioElement)).toThrow('Недоступная демонстрация')
  })

  it('mutes the one selected screen-audio element while deafened', () => {
    const selected = stream('alice')
    const controller = new ScreenViewerController(() => [selected])
    const audio = { muted: false } as HTMLAudioElement

    controller.select('alice', {} as HTMLVideoElement, audio)
    controller.setDeafened(true)

    expect(audio.muted).toBe(true)
    controller.setDeafened(false)
    expect(audio.muted).toBe(false)
  })

})
