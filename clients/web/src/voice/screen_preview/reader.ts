import { readScreenPreview, ScreenPreviewMissing, type ScreenPreviewFrame, type ScreenPreviewHint } from './client'
import type { ScreenPreviewRequest } from './client'
import type { ScreenPreviewVisibilitySource } from './visibility'
import { refreshScreenPreviewVisibility, scheduleScreenPreviewPoll, type ScreenPreviewReaderState } from './reader_visibility_control'
import { screenMediaRollout } from '../screen_rollout/policy'

const legacyVisibility: ScreenPreviewVisibilitySource = { isVisible: () => true, subscribe: () => () => undefined }

type State = ScreenPreviewReaderState
export interface ScreenPreviewSink { apply(hint: ScreenPreviewHint, bytes: Uint8Array): void; clear(leaseId: string): void }
export interface ScreenPreviewReaderOptions { visibility?: ScreenPreviewVisibilitySource; random?: () => number; enabled?: boolean }

export class LatestScreenPreviewReader {
  private readonly states = new Map<string, State>()
  private readonly visibility: ScreenPreviewVisibilitySource
  private readonly random: () => number
  private stopWatching: (() => void) | null = null
  private readonly enabled: boolean

  constructor(private readonly sink: ScreenPreviewSink, private readonly request: ScreenPreviewRequest = fetch, private readonly read = readScreenPreview, options: ScreenPreviewReaderOptions = {}) {
    this.enabled = options.enabled ?? screenMediaRollout().jpegPreview
    this.visibility = options.visibility ?? legacyVisibility
    this.random = options.random ?? Math.random
    this.resume()
  }

  resume(): void {
    if (!this.enabled) return
    if (!this.stopWatching) this.stopWatching = this.visibility.subscribe(() => this.refreshVisibility())
    this.refreshVisibility()
  }

  accept(hint: ScreenPreviewHint): void {
    if (!this.enabled) return
    let state = this.states.get(hint.leaseId)
    if (state?.hint.generationId !== hint.generationId) {
      this.sink.clear(hint.leaseId)
      if (state?.timer) clearTimeout(state.timer)
      this.states.delete(hint.leaseId)
      state = undefined
    }
    if (!state) {
      if (this.states.size >= 16) this.evictOldest()
      state = { hint, revision: 0, pending: 0, running: false, poll: false, visible: this.visibility.isVisible(hint.leaseId), failures: 0, initialRetries: 0 }
      this.states.set(hint.leaseId, state)
    }
    state.hint = hint
    state.pending = Math.max(state.pending, hint.revision)
    if (state.visible && !state.running) void this.pump(hint.leaseId, state)
  }

  invalidate(leaseId: string, generationId: string): void {
    const state = this.states.get(leaseId)
    if (!state || state.hint.generationId !== generationId) return
    if (state.timer) clearTimeout(state.timer)
    this.states.delete(leaseId)
    this.sink.clear(leaseId)
  }

  clear(): void {
    this.states.forEach((state, leaseId) => { if (state.timer) clearTimeout(state.timer); this.sink.clear(leaseId) })
    this.states.clear()
    this.stopWatching?.()
    this.stopWatching = null
  }

  private evictOldest(): void {
    const leaseId = this.states.keys().next().value
    if (!leaseId) return
    const state = this.states.get(leaseId)
    if (state?.timer) clearTimeout(state.timer)
    this.states.delete(leaseId)
    this.sink.clear(leaseId)
  }

  private refreshVisibility(): void {
    refreshScreenPreviewVisibility(this.states, this.visibility, (leaseId, state) => { void this.pump(leaseId, state) })
  }

  private async pump(leaseId: string, state: State): Promise<void> {
    if (this.states.get(leaseId) !== state || !this.visibility.isVisible(leaseId)) return
    state.visible = true
    state.running = true
    try {
      while (this.states.get(leaseId) === state && this.visibility.isVisible(leaseId) && (state.pending > state.revision || state.poll)) {
        const hint = state.hint, target = state.pending
        state.pending = state.revision
        state.poll = false
        let frame: ScreenPreviewFrame | null = null
        try { frame = await this.read(hint, state.revision, this.request) }
        catch (cause) {
          if (cause instanceof ScreenPreviewMissing && this.states.get(leaseId) === state) { this.invalidate(leaseId, hint.generationId); return }
          if (this.states.get(leaseId) === state) state.failures += 1
          break
        }
        if (this.states.get(leaseId) !== state || state.hint.generationId !== hint.generationId) return
        if (!this.visibility.isVisible(leaseId)) { state.pending = Math.max(state.pending, target); state.poll = true; break }
        state.failures = 0
        if (frame && frame.revision > state.revision) {
          state.revision = frame.revision
          if (state.pending <= frame.revision) this.sink.apply(hint, frame.bytes)
        }
      }
    } finally {
      state.running = false
      if (this.states.get(leaseId) === state && this.visibility.isVisible(leaseId)) {
        scheduleScreenPreviewPoll(leaseId, state, this.states, this.visibility, (id, next) => { void this.pump(id, next) }, this.random)
      }
    }
  }
}
