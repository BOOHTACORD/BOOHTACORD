import { SoundBurstLimit } from './limit'
import type { VoiceMember, VoiceSoundEvent, VoiceStream } from './types'
export type { VoiceSoundEvent } from './types'

type Pending = { event: VoiceSoundEvent; due: number }
const settleMs = 1200
const staleMs = 5000

export class VoiceSoundPolicy {
  private active = false
  private readonly members = new Map<string, string>()
  private readonly streams = new Map<string, Set<string>>()
  private readonly leaves = new Map<string, Pending>()
  private readonly stops = new Map<string, Pending>()
  private readonly seen = new Set<string>()
  private readonly limit = new SoundBurstLimit()

  constructor(private readonly channel: string, private readonly self: string, private readonly play: (event: VoiceSoundEvent) => void) {}

  seed(members: VoiceMember[], streams: VoiceStream[]): void {
    this.pause()
    for (const m of members) this.members.set(m.actor, m.lease)
    for (const s of streams) this.streamSet(s.actor).add(s.session)
    this.active = true
  }
  pause(): void {
    this.active = false; this.members.clear(); this.streams.clear(); this.leaves.clear(); this.stops.clear(); this.seen.clear()
  }
  accept(e: VoiceSoundEvent, now: number): void {
    if (!this.active || e.channel !== this.channel || !e.actor || e.actor === this.self || e.actor.startsWith('voice-lease:') || !e.session || !e.id || !Number.isFinite(e.time) || !Number.isFinite(now) || e.time < now - staleMs || e.time > now + 1000) return
    const key = `${e.id}\0${e.actor}\0${e.session}`
    if (this.seen.has(key)) return
    this.seen.add(key)
    if (this.seen.size > 256) this.seen.delete(this.seen.values().next().value!)
    if (e.type !== 'voice.member_left') this.flush(now)
    switch (e.type) {
      case 'voice.member_joined': this.join(e, now); break
      case 'voice.member_left':
        if (this.members.get(e.actor) === e.session) this.leaves.set(e.actor, { event: e, due: now + settleMs })
        this.flush(now)
        break
      case 'voice.stream_started': this.start(e, now); break
      case 'voice.stream_stopped':
        if (this.streams.get(e.actor)?.has(e.session)) this.stops.set(`${e.actor}\0${e.session}`, { event: e, due: now + settleMs })
        break
    }
  }
  flush(now: number): void {
    if (!this.active || !Number.isFinite(now)) return
    for (const [actor, item] of this.leaves) if (item.due <= now) this.finishLeave(actor, item.event, now)
    for (const [key, item] of this.stops) if (item.due <= now) {
      this.stops.delete(key)
      if (!this.leaves.has(item.event.actor) && this.members.has(item.event.actor)) {
        this.streams.get(item.event.actor)?.delete(item.event.session); this.emit(item.event, now)
      }
    }
  }
  private join(e: VoiceSoundEvent, now: number): void {
    const pending = this.leaves.get(e.actor)
    if (pending && pending.event.session === e.session) { this.leaves.delete(e.actor); return }
    if (pending) this.finishLeave(e.actor, pending.event, now)
    if (this.members.get(e.actor) === e.session) return
    this.members.set(e.actor, e.session); this.emit(e, now)
  }
  private start(e: VoiceSoundEvent, now: number): void {
    if (!this.members.has(e.actor) || this.leaves.has(e.actor)) return
    const key = `${e.actor}\0${e.session}`
    if (this.stops.delete(key)) return
    if (this.streamSet(e.actor).has(e.session)) return
    this.streamSet(e.actor).add(e.session); this.emit(e, now)
  }
  private finishLeave(actor: string, event: VoiceSoundEvent, now: number): void {
    this.leaves.delete(actor); this.members.delete(actor); this.streams.delete(actor)
    for (const [key, item] of this.stops) if (item.event.actor === actor) this.stops.delete(key)
    this.emit(event, now)
  }
  private streamSet(actor: string): Set<string> {
    let value = this.streams.get(actor)
    if (!value) { value = new Set<string>(); this.streams.set(actor, value) }
    return value
  }
  private emit(event: VoiceSoundEvent, now: number): void { if (event.time >= now - staleMs && this.limit.allow(now)) this.play(event) }
}
