import { beginScreenPreview, invalidateScreenPreview, type ScreenPreviewRequest } from './client'
import { ScreenPreviewRequestScopes } from './request_scopes'
import { screenMediaRollout } from '../screen_rollout/policy'

const shutdownGraceMs = 250
const leaseRefreshMs = 30_000

async function settlesWithin(operation: Promise<unknown>): Promise<boolean> {
  let timer!: ReturnType<typeof setTimeout>
  const settled = operation.then(() => true, () => true)
  return Promise.race([settled, new Promise<boolean>((resolve) => { timer = setTimeout(() => resolve(false), shutdownGraceMs) })])
    .finally(() => clearTimeout(timer))
}

/** Keeps the server-owned LiveKit Egress capture alive; no frame bytes leave this client. */
export class LatestScreenPreviewUploader {
  private leaseId = ''
  private generationId = ''
  private beginning: Promise<void> | null = null
  private stopping: Promise<void> | null = null
  private refreshTimer: ReturnType<typeof setInterval> | null = null
  private epoch = 0
  private lastBeginAt = 0
  private requestScopes: ScreenPreviewRequestScopes

  constructor(request: ScreenPreviewRequest = fetch, private readonly enabled = screenMediaRollout().jpegPreview) {
    this.requestScopes = new ScreenPreviewRequestScopes(request)
  }

  private async invalidateBounded(leaseId: string, generationId: string): Promise<void> {
    const scope = this.requestScopes.create()
    const operation = invalidateScreenPreview(leaseId, generationId, scope.request).catch(() => undefined).finally(scope.release)
    if (!await settlesWithin(operation)) { scope.abort(); scope.release() }
  }

  async start(leaseId: string): Promise<void> {
    if (!this.enabled) return
    if (this.leaseId !== leaseId) {
      const previous = this.generationId ? { leaseId: this.leaseId, generationId: this.generationId } : null
      this.epoch++
      this.leaseId = leaseId
      this.generationId = ''
      this.lastBeginAt = 0
      this.beginning = null
      this.startRefreshTimer(leaseId)
      if (previous) await this.invalidateBounded(previous.leaseId, previous.generationId)
    }
    if (this.beginning) return this.beginning
    if (this.generationId && Date.now() - this.lastBeginAt < leaseRefreshMs) return

    const epoch = this.epoch
    this.lastBeginAt = Date.now()
    const operation = (async () => {
      const scope = this.requestScopes.create()
      let generationId: string
      try { generationId = await beginScreenPreview(leaseId, scope.request) } finally { scope.release() }
      if (epoch !== this.epoch || leaseId !== this.leaseId) {
        await this.invalidateBounded(leaseId, generationId)
        return
      }
      this.generationId = generationId
    })()
    this.beginning = operation
    try { await operation } finally { if (this.beginning === operation) this.beginning = null }
  }

  private startRefreshTimer(leaseId: string): void {
    if (this.refreshTimer) clearInterval(this.refreshTimer)
    this.refreshTimer = setInterval(() => {
      if (this.leaseId === leaseId) void this.start(leaseId).catch(() => undefined)
    }, leaseRefreshMs)
  }

  stop(): Promise<void> {
    if (this.stopping) return this.stopping
    let shared!: Promise<void>
    shared = this.stopCurrent().finally(() => {
      if (this.stopping === shared) this.stopping = null
    })
    this.stopping = shared
    return shared
  }

  private async stopCurrent(): Promise<void> {
    ++this.epoch
    const leaseId = this.leaseId, generationId = this.generationId
    const beginning = this.beginning
    if (this.refreshTimer) clearInterval(this.refreshTimer)
    this.refreshTimer = null
    this.leaseId = ''
    this.generationId = ''
    this.lastBeginAt = 0
    this.requestScopes.abortAll()
    await settlesWithin(beginning?.catch(() => undefined) ?? Promise.resolve())
    if (leaseId && generationId) await this.invalidateBounded(leaseId, generationId)
  }
}
