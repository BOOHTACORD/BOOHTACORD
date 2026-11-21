interface Entry { promise: Promise<void>; finish: () => void; fail: (cause: unknown) => void;
  timer: ReturnType<typeof setTimeout>; running: boolean; dirty: boolean; fetch: () => Promise<void> }
export function createProtectedRefreshGate(windowMs = 25) {
  const entries = new Map<string, Entry>()
  let active = true
  async function drain(key: string, entry: Entry): Promise<void> {
    entry.running = true
    try {
      do { entry.dirty = false; if (active) await entry.fetch() } while (active && entry.dirty)
      entry.finish()
    } catch (cause) { entry.fail(cause) }
    finally { if (entries.get(key) === entry) entries.delete(key) }
  }
  return {
    current: () => active,
    run(key: string, fetch: () => Promise<void>): Promise<void> {
      if (!active) return Promise.resolve()
      const current = entries.get(key)
      if (current) { current.fetch = fetch; if (current.running) current.dirty = true; return current.promise }
      let finish!: () => void, fail!: (cause: unknown) => void
      const promise = new Promise<void>((resolve, reject) => { finish = resolve; fail = reject })
      const entry: Entry = { promise, finish, fail, timer: setTimeout(() => { void drain(key, entry) }, windowMs),
        running: false, dirty: false, fetch }
      entries.set(key, entry)
      return promise
    },
    close(): void {
      active = false
      for (const entry of entries.values()) { clearTimeout(entry.timer); if (!entry.running) entry.finish() }
      entries.clear()
    },
  }
}
