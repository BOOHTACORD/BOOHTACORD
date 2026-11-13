import { createHash } from 'node:crypto'
import { createRequire } from 'node:module'
import { access, mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const webRoot = fileURLToPath(new URL('../../../clients/web/', import.meta.url))
const feature = join(webRoot, 'src/voice/noise_suppression')
export const expected = {
  'dfn_bg.wasm': '0745651e0b7a0993e8a4d71320840d28754c112425906b6f0e93f4c770724fec',
  'dfn.js': '1e6adbcb777c92a03b09051f8f43b76a382f3e0489e4ff38ec4a9ebbbae75979',
  'model.bin': 'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616',
}
const digest = bytes => createHash('sha256').update(bytes).digest('hex')

export async function prepareAssets(bundle) {
  const artifacts = new Map()
  for (const [file, checksum] of Object.entries(expected)) {
    const bytes = await readFile(join(bundle, file))
    if (digest(bytes) !== checksum) throw new Error(`Invalid ${file} checksum`)
    artifacts.set(file === 'dfn.js' ? 'deepfilter/dfn.js' : file, bytes)
  }
  const ts = createRequire(join(webRoot, 'package.json'))('typescript')
  if (ts.version !== '5.9.3') throw new Error('Unexpected TypeScript version')
  const transpile = async file => {
    const result = ts.transpileModule(await readFile(file, 'utf8'), {
      fileName: file, reportDiagnostics: true,
      compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
    })
    if (result.diagnostics?.some(item => item.category === ts.DiagnosticCategory.Error)) throw new Error('Worklet transpilation failed')
    return Buffer.from(result.outputText)
  }
  artifacts.set('deepfilter/core.js', await transpile(join(feature, 'deepfilter/core.ts')))
  artifacts.set('ring_buffer.js', await transpile(join(feature, 'ring_buffer.ts')))
  for (const name of ['worklet.js', 'worklet_env.js'])
    artifacts.set(`deepfilter/${name}`, await readFile(join(feature, 'deepfilter', name)))
  return artifacts
}

export async function stage({ bundle, output }) {
  try { await access(output); throw new Error('Destination already exists') }
  catch (error) { if (error.code !== 'ENOENT') throw error }
  const artifacts = await prepareAssets(bundle)
  await mkdir(output)
  for (const [name, bytes] of artifacts) {
    const path = join(output, name); await mkdir(dirname(path), { recursive: true }); await writeFile(path, bytes)
  }
  return { scope: 'research-only', artifacts: expected }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 4) throw new Error('Usage: node stage.mjs <research-bundle> <new-output>')
  await stage({ bundle: process.argv[2], output: process.argv[3] })
  console.log('Prepared research-only Web worklet assets; not approved for release.')
}
