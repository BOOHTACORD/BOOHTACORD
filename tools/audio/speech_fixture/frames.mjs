/** Offline only: keep model tail so a delayed final syllable is not truncated. */
export function processFrames(input, frameSize, tailFrames, processFrame) {
  if (!Number.isInteger(frameSize) || frameSize < 1 || !Number.isInteger(tailFrames) || tailFrames < 0) {
    throw new Error('invalid frame configuration')
  }
  if (!input.every(Number.isFinite)) throw new Error('nonfinite input')
  const frameCount = Math.ceil(input.length / frameSize) + tailFrames
  const output = new Float32Array(frameCount * frameSize)
  for (let index = 0; index < frameCount; index++) {
    const frame = new Float32Array(frameSize)
    frame.set(input.subarray(index * frameSize, (index + 1) * frameSize))
    const processed = processFrame(frame)
    if (processed.length !== frameSize) throw new Error('invalid output frame')
    if (!processed.every(Number.isFinite)) throw new Error('nonfinite output')
    output.set(processed, index * frameSize)
  }
  return output
}
