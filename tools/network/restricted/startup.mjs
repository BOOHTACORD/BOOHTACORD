// HTTP availability must not race Vite's first optimized dependency generation.
const entry = '/tests/restricted_networks/fixture.html'
export function fixtureStartup(server) {
  let ready = false
  return {
    async warm() {
      const module = await server.transformRequest('/tests/restricted_networks/fixture.ts')
      if (!module) throw new Error('Restricted-network fixture module did not transform')
      await server.waitForRequestsIdle()
      ready = true
    },
    middleware(request, response, next) {
      if (request.url !== entry) { next(); return }
      if (!ready) { response.statusCode = 503; response.end('Fixture modules are starting'); return }
      response.setHeader('X-Restricted-Fixture-Ready', 'modules-warmed')
      next()
    },
  }
}
