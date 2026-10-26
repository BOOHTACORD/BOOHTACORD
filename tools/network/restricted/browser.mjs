import { createRequire } from 'node:module'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'
import { fixtureStartup } from './startup.mjs'
const root = fileURLToPath(new URL('../../../clients/web/', import.meta.url))
const { createServer } = await import(new URL('../../../clients/web/node_modules/vite/dist/node/index.js', import.meta.url))
const { AccessToken } = createRequire(new URL('../../../clients/web/package.json', import.meta.url))('livekit-server-sdk')
const server = await createServer({ root, appType: 'custom', optimizeDeps: { entries: ['tests/restricted_networks/fixture.html'] },
  server: { host: '127.0.0.1', port: 4900, strictPort: true } })
const startup = fixtureStartup(server)
server.middlewares.use(startup.middleware)
server.middlewares.use((request, response, next) => {
  response.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; connect-src 'self' ws://127.0.0.1:4900 ws://127.0.0.1:17880 ws://127.0.0.1:17889; media-src 'self' blob:")
  if (request.url?.startsWith('/network-token?')) {
    const role = new URL(request.url, 'http://127.0.0.1').searchParams.get('role')
    if (role !== 'sender' && role !== 'receiver') { response.statusCode = 400; response.end(); return }
    const token = new AccessToken('devkey', 'secret', { identity: `network-fixture-${role}`, ttl: '2m' })
    token.addGrant({ roomJoin: true, room: 'isolated-network-fixture', canPublish: role === 'sender', canSubscribe: role === 'receiver' })
    response.setHeader('Content-Type', 'application/json'); response.setHeader('Cache-Control', 'no-store')
    const url = process.env.NETWORK_PROFILE === 'signal-blocked' ? 'ws://127.0.0.1:17889' : 'ws://127.0.0.1:17880'
    void token.toJwt().then(value => response.end(JSON.stringify({ token: value, url }))).catch(() => { response.statusCode = 500; response.end() })
    return
  }
  if (request.url === '/tests/restricted_networks/fixture.html') {
    response.setHeader('Content-Type', 'text/html')
    void server.transformIndexHtml(request.url, readFileSync(resolve(root, 'tests/restricted_networks/fixture.html'), 'utf8'))
      .then(value => response.end(value)).catch(() => { response.statusCode = 500; response.end() })
    return
  }
  next()
})
await server.listen()
await startup.warm()
console.log('Restricted-network browser fixture ready')
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, async () => { await server.close(); process.exit(0) })
