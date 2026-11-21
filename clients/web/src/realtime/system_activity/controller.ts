export type IdleDetectorLike = EventTarget & {
  readonly userState: 'active' | 'idle' | null
  readonly screenState: 'locked' | 'unlocked' | null
  start(options: { threshold: number; signal: AbortSignal }): Promise<void>
}
export type ActivityOptions = {
  available: boolean
  create: () => IdleDetectorLike
  createInitial?: () => IdleDetectorLike
  permission: () => Promise<PermissionState>
  report: () => void
  reportInactive?: () => void
  save: (enabled: boolean) => void
  now?: () => number
  unavailable?: () => void
}

export function createSystemActivity(options: ActivityOptions) {
  let detector: IdleDetectorLike | null = null, initial: IdleDetectorLike | null = null, abort: AbortController | null = null
  let timer: ReturnType<typeof setInterval> | null = null, generation = 0
  const now = options.now ?? (() => performance.now())
  let sampledAt = 0, idleSince: number | null = null
  function check() {
    if (detector?.userState === 'idle') idleSince ??= now()
    else idleSince = null
    if (detector?.screenState === 'locked' || detector?.userState === 'idle') options.reportInactive?.()
    else if (detector?.userState === 'active' && detector.screenState === 'unlocked') options.report()
  }
  function changed() { sampledAt = now(); check() }
  function tick() {
    const current = now()
    if (current - sampledAt > 30_000 || current < sampledAt) {
      stop()
      void start(generation)
      return
    }
    sampledAt = current
    check()
  }
  function stop() {
    generation++
    if (timer !== null) clearInterval(timer)
    timer = null
    detector?.removeEventListener('change', changed)
    abort?.abort(); abort = null; detector = null; initial = null; idleSince = null
  }
  async function start(ownGeneration: number): Promise<boolean> {
    try {
      const current = options.create(), controller = new AbortController()
      abort = controller; detector = current
      current.addEventListener('change', changed)
      await current.start({ threshold: 60_000, signal: controller.signal })
      if (generation !== ownGeneration) return false
      if (options.createInitial) {
        try {
          const candidate = options.createInitial()
          await candidate.start({ threshold: 300_000, signal: controller.signal })
          if (generation !== ownGeneration) return false
          initial = candidate
        } catch { initial = null }
      }
      if (generation !== ownGeneration) return false
      sampledAt = now(); check(); timer = setInterval(tick, 15_000)
      return true
    } catch {
      if (generation === ownGeneration) { stop(); options.unavailable?.() }
      return false
    }
  }
  async function enable(): Promise<boolean> {
    if (!options.available) return false
    stop(); const ownGeneration = generation
    try {
      if (await options.permission() !== 'granted' || generation !== ownGeneration) return false
      if (!await start(ownGeneration)) return false
      options.save(true); return true
    } catch { return false }
  }
  async function restore(granted: () => Promise<boolean>): Promise<boolean> {
    if (!options.available) return false
    stop(); const ownGeneration = generation
    try {
      if (!await granted() || generation !== ownGeneration) return false
      return await start(ownGeneration)
    } catch { return false }
  }
  function disable() { stop(); options.save(false) }
  const allowAppInteraction = () => detector?.screenState !== 'locked'
  const isConfirmedIdle = () => {
    const current = now()
    const fresh = current >= sampledAt && current - sampledAt <= 30_000
    return fresh && detector?.userState === 'idle' &&
      (initial?.userState === 'idle' || (idleSince !== null && current - idleSince >= 240_000))
  }
  return { available: options.available, enable, restore, disable, stop, allowAppInteraction, isConfirmedIdle }
}
