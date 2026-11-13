import { readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'

const expected = [
  '1e6adbcb777c92a03b09051f8f43b76a382f3e0489e4ff38ec4a9ebbbae75979',
  '0745651e0b7a0993e8a4d71320840d28754c112425906b6f0e93f4c770724fec',
  'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616',
]

/** Only the identified research build is supported; this is not a release loader. */
export async function loadResearchEngine(paths) {
  if (paths.length !== 3) throw new Error('Provide generated JS glue, WASM and model paths')
  const bytes = paths.map(path => readFileSync(path))
  const hashes = bytes.map(value => createHash('sha256').update(value).digest('hex'))
  if (hashes.some((value, index) => value !== expected[index])) throw new Error('research asset checksum mismatch')
  const api = await import(`data:text/javascript;base64,${bytes[0].toString('base64')}`)
  api.initSync({ module: new WebAssembly.Module(bytes[1]) })
  const engine = new api.Denoiser(bytes[2], 25)
  if (engine.frame_size() !== 480) { engine.free(); throw new Error('unexpected frame size') }
  return { engine, hashes }
}
