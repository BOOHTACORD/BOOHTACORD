const contentType = file => file.endsWith('.wasm') ? 'application/wasm'
  : file.endsWith('.js') ? 'application/javascript' : file.endsWith('.json')
    ? 'application/json' : file.endsWith('.bin') ? 'application/octet-stream' : 'text/plain; charset=utf-8'

export function verifiedAssetsPlugin({ name, prefix, enabled, prepare }) {
  let pending
  const assets = () => pending ??= prepare()
  return {
    name,
    async buildStart() { if (enabled) await assets() },
    async configureServer(server) {
      if (!enabled) return
      const files = await assets()
      server.middlewares.use((request, response, next) => {
        const path = request.url?.split('?')[0]
        if (!path?.startsWith('/' + prefix)) return next()
        const file = path.slice(prefix.length + 1), bytes = files.get(file)
        if (!bytes) return next()
        response.setHeader('Content-Type', contentType(file))
        response.setHeader('Content-Length', bytes.length)
        response.setHeader('Cache-Control', 'no-store')
        response.end(bytes)
      })
    },
    async generateBundle() {
      if (!enabled) return
      for (const [file, source] of await assets())
        this.emitFile({ type: 'asset', fileName: prefix + file, source })
    },
  }
}
