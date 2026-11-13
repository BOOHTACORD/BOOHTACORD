const roots = ['/audio/dfn-research/', '/audio/deepfilternet/research-d375b2d/']
const files = new Map([
  ['dfn_bg.wasm', 'application/wasm'], ['model.bin', 'application/octet-stream'],
  ['ring_buffer.js', 'text/javascript'], ['deepfilter/core.js', 'text/javascript'],
  ['deepfilter/dfn.js', 'text/javascript'], ['deepfilter/worklet.js', 'text/javascript'],
  ['deepfilter/worklet_env.js', 'text/javascript'],
])
export function researchAsset(url) {
  const path = url?.split('?', 1)[0]
  const root = roots.find(prefix => path?.startsWith(prefix))
  if (!root) return undefined
  const file = path.slice(root.length), type = files.get(file)
  return type ? [file, type] : undefined
}
