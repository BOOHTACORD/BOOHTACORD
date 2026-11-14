export interface PreflightMetrics { ready: boolean; p95Ms: number; maxMs: number; elapsedMs: number; frames: number }

export function eligible(value: unknown): value is PreflightMetrics {
  if (!value || typeof value !== 'object') return false
  const v = value as PreflightMetrics
  return v.ready === true && v.frames === 32 &&
    [v.p95Ms, v.maxMs, v.elapsedMs].every(Number.isFinite) &&
    v.p95Ms >= 0 && v.p95Ms <= 3 && v.maxMs >= v.p95Ms && v.maxMs <= 8 &&
    v.elapsedMs >= v.maxMs && v.elapsedMs <= 1000
}

/** Synthetic eligibility only. Dedicated worker; no capture or speech samples. */
export function benchmark(process: (frame: Float32Array) => Float32Array, now = () => performance.now()): PreflightMetrics {
  const result = { ready: false, p95Ms: 0, maxMs: 0, elapsedMs: 0, frames: 0 }
  const frame = new Float32Array(480), times: number[] = []
  const start = now()
  let previous = start, seed = 687
  try {
    for (let step = 0; step < 40; step++) {
      for (let i = 0; i < frame.length; i++) {
        seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0
        frame[i] = (seed / 4294967296 - .5) * .02 + Math.sin((step * 480 + i) * .031) * .05
      }
      const before = now(), output = process(frame), after = now()
      if (![before, after].every(Number.isFinite) || before < previous || after < before) return result
      previous = after
      result.elapsedMs = after - start
      if (output.length !== 480 || output.some(value => !Number.isFinite(value) || Math.abs(value) > 1) || result.elapsedMs > 1000) return result
      if (step >= 8) times.push(after - before)
    }
    times.sort((a, b) => a - b)
    result.p95Ms = times[30]; result.maxMs = times[31]; result.frames = times.length
    result.ready = true
    result.ready = eligible(result)
  } catch { /* A trapped model is ineligible; caller terminates its worker. */ }
  return result
}
