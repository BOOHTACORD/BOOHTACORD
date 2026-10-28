import { readFileSync } from 'node:fs'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { LatestScreenPreviewReader } from './reader'
import { screenPreviewRetryDelay } from './reader_retry'
import { replaceScreenPreviewParticipantLeases, screenPreviewLeaseForParticipant } from './participant_leases'
import { ScreenPreviewCardVisibility } from './visibility'
import type { ScreenPreviewFrame, ScreenPreviewHint } from './client'

const lease = '11111111-1111-4111-8111-111111111111'
const hint: ScreenPreviewHint = { leaseId: lease, generationId: 'generation-1', revision: 1 }
const frame: ScreenPreviewFrame = { revision: 2, bytes: new Uint8Array([0xff, 0xd8, 0xff, 0xd9]) }
function visibility() {
  const listeners: (() => void)[] = []
  const fakeDocument = { visibilityState: 'visible', addEventListener: (_: string, listener: () => void) => listeners.push(listener) }
  vi.stubGlobal('document', fakeDocument)
  const source = new ScreenPreviewCardVisibility()
  const card = {} as Element
  return {
    source,
    setDocument: (visible: boolean) => { fakeDocument.visibilityState = visible ? 'visible' : 'hidden'; listeners.forEach((listener) => listener()) },
    setCard: (visible: boolean) => source.setCardVisible(card, lease, visible),
  }
}

const settle = async () => { await Promise.resolve(); await Promise.resolve() }
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })
describe('private screen preview reader visibility', () => {
  it('requires a visible card and foreground document before reading', async () => {
    const state = visibility()
    const read = vi.fn().mockResolvedValue(null)
    const reader = new LatestScreenPreviewReader({ apply: vi.fn(), clear: vi.fn() }, vi.fn(), read, { visibility: state.source })
    reader.accept(hint)
    await settle()
    expect(read).not.toHaveBeenCalled()
    state.setDocument(false)
    state.setCard(true)
    await settle()
    expect(read).not.toHaveBeenCalled()
    state.setDocument(true)
    expect(state.source.isVisible(lease)).toBe(true)
    await settle()
    expect(read).toHaveBeenCalledOnce()
    reader.clear()
  })

  it('retries an empty initial preview quickly, then polls each frame every 30 seconds', async () => {
    vi.useFakeTimers()
    const state = visibility()
    state.setCard(true)
    const read = vi.fn().mockResolvedValueOnce(null).mockResolvedValue(frame)
    const apply = vi.fn()
    const reader = new LatestScreenPreviewReader({ apply, clear: vi.fn() }, vi.fn(), read, { visibility: state.source })
    reader.accept(hint)
    await settle()
    expect(read).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(999)
    expect(read).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(1)
    expect(read).toHaveBeenCalledTimes(2)
    expect(apply).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(29_999)
    expect(read).toHaveBeenCalledTimes(2)
    await vi.advanceTimersByTimeAsync(1)
    expect(read).toHaveBeenCalledTimes(3)
    reader.clear()
  })

  it('bounds empty initial retries before switching to the 30-second poll interval', async () => {
    vi.useFakeTimers()
    const state = visibility()
    state.setCard(true)
    const read = vi.fn().mockResolvedValue(null)
    const reader = new LatestScreenPreviewReader({ apply: vi.fn(), clear: vi.fn() }, vi.fn(), read, { visibility: state.source })
    reader.accept(hint)
    await settle()
    expect(read).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(3_000)
    expect(read).toHaveBeenCalledTimes(4)
    await vi.advanceTimersByTimeAsync(29_999)
    expect(read).toHaveBeenCalledTimes(4)
    await vi.advanceTimersByTimeAsync(1)
    expect(read).toHaveBeenCalledTimes(5)
    reader.clear()
  })

  it('pauses polling while hidden and reads immediately on visibility return', async () => {
    vi.useFakeTimers()
    const state = visibility()
    state.setCard(true)
    expect(state.source.isVisible(lease)).toBe(true)
    const read = vi.fn().mockResolvedValue(frame)
    const reader = new LatestScreenPreviewReader({ apply: vi.fn(), clear: vi.fn() }, vi.fn(), read, { visibility: state.source })
    reader.accept(hint)
    await settle()
    await vi.advanceTimersByTimeAsync(29_999)
    expect(read).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(1)
    expect(read).toHaveBeenCalledTimes(2)
    state.setDocument(false)
    await vi.advanceTimersByTimeAsync(20_000)
    expect(read).toHaveBeenCalledTimes(2)
    state.setDocument(true)
    await settle()
    expect(read).toHaveBeenCalledTimes(3)
    reader.clear()
  })

  it('discards an in-flight response after card visibility is lost', async () => {
    let finish!: (value: ScreenPreviewFrame | null) => void
    const state = visibility()
    state.setCard(true)
    const read = vi.fn().mockImplementationOnce(() => new Promise<ScreenPreviewFrame | null>((resolve) => { finish = resolve }))
      .mockResolvedValue(null)
    const apply = vi.fn()
    const reader = new LatestScreenPreviewReader({ apply, clear: vi.fn() }, vi.fn(), read, { visibility: state.source })
    reader.accept(hint)
    state.setCard(false)
    finish(frame)
    await settle()
    expect(apply).not.toHaveBeenCalled()
    state.setCard(true)
    await settle()
    expect(read).toHaveBeenCalledTimes(2)
    reader.clear()
  })

  it('retries failures after bounded jittered delay only while the card is visible', async () => {
    vi.useFakeTimers()
    const state = visibility()
    state.setCard(true)
    const read = vi.fn().mockRejectedValueOnce(new Error('temporary read failure')).mockResolvedValue(null)
    const reader = new LatestScreenPreviewReader({ apply: vi.fn(), clear: vi.fn() }, vi.fn(), read, { visibility: state.source, random: () => 0 })
    reader.accept(hint)
    await settle()
    expect(read).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(799)
    expect(read).toHaveBeenCalledOnce()
    state.setCard(false)
    await vi.advanceTimersByTimeAsync(1)
    expect(read).toHaveBeenCalledOnce()
    state.setCard(true)
    await settle()
    expect(read).toHaveBeenCalledTimes(2)
    reader.clear()
  })

  it('maps the voice lease identity to the rail card and applies bounded jittered retries', () => {
    replaceScreenPreviewParticipantLeases([['account-1', lease]])
    expect(screenPreviewLeaseForParticipant('account-1')).toBe(lease)
    replaceScreenPreviewParticipantLeases([])
    const adapter = readFileSync(new URL('../livekit_screen_viewer_adapter.ts', import.meta.url), 'utf8')
    expect(adapter).toContain("previewLeaseId: participant.identity.startsWith('voice-lease:')")
    const rail = readFileSync(new URL('../ScreenViewerRail.vue', import.meta.url), 'utf8')
    expect(rail).toContain(':data-screen-preview-lease="screenPreviewLeaseForParticipant(stream.participantId)"')
    expect(rail).toContain('entry.intersectionRatio >= 0.25')
    const workspace = readFileSync(new URL('../../workspace/workspace_realtime.ts', import.meta.url), 'utf8')
    expect(workspace).toContain('visibility: screenPreviewCardVisibility')
    expect(screenPreviewRetryDelay(1, () => 0)).toBe(800)
    expect(screenPreviewRetryDelay(1, () => 1)).toBe(1_200)
    expect(screenPreviewRetryDelay(99, () => 1)).toBe(30_000)
  })
})
