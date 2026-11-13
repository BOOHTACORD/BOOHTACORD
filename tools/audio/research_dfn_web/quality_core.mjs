import { performance } from 'node:perf_hooks'

/** Offline synthetic fixtures only; no call or microphone data. */
export function filterFrames(engine, input) {
  if (!(input instanceof Float32Array) || !input.length || input.length % 480) throw new Error('invalid frames')
  if (!input.every(Number.isFinite)) throw new Error('nonfinite input')
  engine.reset()
  const output = new Float32Array(input.length), durations = []
  for (let offset = 0; offset < input.length; offset += 480) {
    const start = performance.now()
    const frame = engine.process(input.subarray(offset, offset + 480))
    durations.push(performance.now() - start)
    if (!(frame instanceof Float32Array) || frame.length !== 480) throw new Error('invalid output frame')
    if (!frame.every(Number.isFinite)) throw new Error('nonfinite output')
    output.set(frame, offset)
  }
  return { output, durations }
}
