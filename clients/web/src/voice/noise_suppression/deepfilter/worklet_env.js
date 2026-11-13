// AudioWorklet may lack browser globals required by wasm-bindgen.
const pools = new WeakMap()
let active
export function setEntropy(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length !== 65536) throw new Error('entropy unavailable')
  pools.set(bytes, { offset: 0 })
  return bytes
}
export function withEntropy(bytes, callback) {
  if (!pools.has(bytes)) throw new Error('entropy unavailable')
  const previous = active
  active = bytes
  try { return callback() } finally { active = previous }
}
export function takeEntropy(target) {
  const pool = active && pools.get(active)
  if (!pool) throw new Error('entropy unavailable')
  const bytes = new Uint8Array(target.buffer, target.byteOffset, target.byteLength)
  if (pool.offset + bytes.length > active.length) throw new Error('entropy exhausted')
  for (let i = 0; i < bytes.length; i++) { bytes[i] = active[pool.offset]; active[pool.offset++] = 0 }
  return target
}
export function releaseEntropy(bytes) {
  if (!bytes) return
  bytes.fill(0)
  pools.delete(bytes)
}

if (typeof globalThis.TextDecoder !== 'function') {
  globalThis.TextDecoder = class {
    decode(input) {
      if (input === undefined) return ''
      const bytes = ArrayBuffer.isView(input)
        ? new Uint8Array(input.buffer, input.byteOffset, input.byteLength) : new Uint8Array(input)
      if (bytes.length > 65536) throw new Error('text too large')
      let encoded = ''
      for (const byte of bytes) encoded += '%' + byte.toString(16).padStart(2, '0')
      return decodeURIComponent(encoded)
    }
  }
}

if (!globalThis.crypto?.getRandomValues) {
  globalThis.crypto = { getRandomValues: takeEntropy }
}
