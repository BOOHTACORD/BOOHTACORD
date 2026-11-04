import type { VoiceJoinMode } from '../livekit_gateway'

export interface VoiceRecoveryTarget {
  channelId: string
  leaseId: string
  joinMode: VoiceJoinMode
  deafened: boolean
}

export type RecoveryOutcome = 'restored' | 'retry' | 'stop'

// SDK reconnect is bounded. A second, cancellable layer fetches a fresh
// server-issued credential after long outages, without forcing a lease transfer.
export class VoiceRecoveryLoop {
  private epoch = 0
  private timer: ReturnType<typeof setTimeout> | null = null
  private target: VoiceRecoveryTarget | null = null
  private failures = 0

  constructor(
    private readonly attempt: (target: VoiceRecoveryTarget, current: () => boolean) => Promise<RecoveryOutcome>,
    private readonly waiting: () => void,
    private readonly random: () => number = Math.random,
  ) {}

  get active(): boolean { return this.target !== null }
  get channelId(): string | null { return this.target?.channelId ?? null }
  get leaseId(): string | null { return this.target?.leaseId ?? null }

  start(target: VoiceRecoveryTarget): void {
    this.cancel()
    this.target = target
    const epoch = this.epoch
    this.waiting()
    this.schedule(target, epoch, 1000)
  }

  cancel(): void {
    this.epoch++
    if (this.timer !== null) clearTimeout(this.timer)
    this.timer = null
    this.target = null
    this.failures = 0
  }

  private schedule(target: VoiceRecoveryTarget, epoch: number, delay: number): void {
    this.timer = setTimeout(() => {
      this.timer = null
      void this.recover(target, epoch)
    }, delay)
  }

  private async recover(target: VoiceRecoveryTarget, epoch: number): Promise<void> {
    const current = () => this.epoch === epoch && this.target === target
    if (!current()) return
    let outcome: RecoveryOutcome
    try { outcome = await this.attempt(target, current) }
    catch { outcome = 'retry' }
    if (!current()) return
    if (outcome !== 'retry') { this.cancel(); return }
    this.waiting()
    const base = Math.min(1000 * 2 ** Math.min(this.failures++, 5), 30000)
    this.schedule(target, epoch, Math.floor(base * (0.8 + this.random() * 0.4)))
  }
}
