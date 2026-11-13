import { createRequire } from 'node:module'
import { createReadStream, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'
import { warmAudioModules } from './browser_fixture/startup.mjs'
import { researchAsset } from './browser_fixture/research_assets.mjs'
import { fixtureCredentials } from './browser_fixture/credentials.mjs'
const root = fileURLToPath(new URL('../../clients/web/', import.meta.url))
const { createServer } = await import(new URL('../../clients/web/node_modules/vite/dist/node/index.js', import.meta.url))
const { AccessToken } = createRequire(new URL('../../clients/web/package.json', import.meta.url))('livekit-server-sdk')
const livekitUrl = process.env.RNNOISE_LIVEKIT_URL ?? 'ws://127.0.0.1:17880'
const fixtureAuth = fixtureCredentials(process.env)
const server = await createServer({ root,
  optimizeDeps: { entries: ['tests/audio/fixture.html'] },
  server: { host: '127.0.0.1', port: 4800, strictPort: true }, appType: 'custom' })
const versionPath = resolve(root, 'public/audio/rnnoise/v0.1-cdf196b/rnnoise-manifest.json')
let modulesWarmed = false
server.middlewares.use((request, response, next) => {
  response.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self'; connect-src 'self' ws://127.0.0.1:4800 ws://127.0.0.1:17880; style-src 'self' 'unsafe-inline'; media-src 'self' blob:")
  const asset = process.env.BOOHTA_RESEARCH_ASSET_DIR && researchAsset(request.url)
  if (asset) {
    response.setHeader('Content-Type', asset[1]); response.setHeader('Cache-Control', 'no-store')
    const stream = createReadStream(resolve(process.env.BOOHTA_RESEARCH_ASSET_DIR, asset[0]))
    stream.on('error', () => { if (!response.headersSent) response.statusCode = 404; response.end() })
    stream.pipe(response); return
  }
  if (request.url?.startsWith('/tests/audio/livekit-token?')) {
    const role = new URL(request.url, 'http://127.0.0.1').searchParams.get('role')
    if (role !== 'sender' && role !== 'receiver') { response.statusCode = 400; response.end(); return }
    const token = new AccessToken(fixtureAuth.key, fixtureAuth.secret, { identity: `rnnoise-fixture-${role}`, ttl: '5m' })
    token.addGrant({ roomJoin: true, room: 'rnnoise-synthetic-local-gate', canPublish: role === 'sender', canSubscribe: role === 'receiver' })
    response.setHeader('Content-Type', 'application/json'); response.setHeader('Cache-Control', 'no-store')
    void token.toJwt().then(value => response.end(JSON.stringify({ token: value, url: livekitUrl }))).catch(() => { response.statusCode = 500; response.end() })
    return
  }
  if (request.url === '/tests/audio/fixture.html') {
    if (!modulesWarmed) { response.statusCode = 503; response.end('Fixture modules are starting'); return }
    response.setHeader('X-Audio-Fixture-Ready', 'modules-warmed')
    response.setHeader('Content-Type', 'text/html')
    const html = readFileSync(resolve(root, 'tests/audio/fixture.html'), 'utf8')
    void server.transformIndexHtml(request.url, html).then(value => response.end(value)).catch(() => {
      response.statusCode = 500; response.end('Fixture HTML transform failed')
    })
    return
  }
  if (request.url === '/audio/rnnoise/html/rnnoise-manifest.json') {
    response.setHeader('Content-Type', 'text/html'); response.end('<html>wrong asset</html>'); return
  }
  if (request.url?.startsWith('/audio/rnnoise/bad-model/')) {
    response.setHeader('Content-Type', 'application/json'); const info = JSON.parse(readFileSync(versionPath)); info.modelSha256 = '0'.repeat(64)
    response.end(JSON.stringify(info)); return
  }
  if (request.url === '/audio/rnnoise/missing-wasm/rnnoise-manifest.json') {
    response.setHeader('Content-Type', 'application/json'); response.end(readFileSync(versionPath)); return
  }
  if (request.url?.startsWith('/audio/rnnoise/') && (request.url.includes('/missing/') || request.url.includes('/missing-wasm/'))) {
    response.statusCode = 404; response.setHeader('Content-Type', 'text/plain'); response.end('Asset not found'); return
  }
  next()
})
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => { await server.close(); process.exit(0) })
await server.listen()
await warmAudioModules(server)
modulesWarmed = true
console.log('RNNoise browser fixture ready at http://127.0.0.1:4800/tests/audio/fixture.html')
