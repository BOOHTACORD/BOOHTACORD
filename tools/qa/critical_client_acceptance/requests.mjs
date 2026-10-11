export function requests(page, channelId) {
  let current = null
  let lastActivity = 0
  const active = new Map(), watched = new Map()
  function kind(request) {
    if (request.method() !== 'GET') return null
    const url = new URL(request.url())
    if (url.pathname === '/api/v1/channels') return 'topology'
    if (url.pathname !== '/api/v1/channels/'+channelId+'/messages') return null
    if (url.searchParams.has('before')) return 'history_before'
    if (url.searchParams.has('after')) return 'history_after'
    if (url.searchParams.has('at')) return 'history_at'
    return 'history_latest'
  }
  function finish(request) {
    const value = watched.get(request)
    if (value) { active.set(value, active.get(value)-1); watched.delete(request); lastActivity = Date.now() }
  }
  page.on('request', request => {
    const value = kind(request)
    if (!value || !current) return
    watched.set(request, value); active.set(value, (active.get(value) ?? 0)+1)
    lastActivity = Date.now()
    current[value]++
    if (value.startsWith('history_')) {
      current.history++
      const parallelHistory = [...active.entries()].reduce((count, [kind, amount]) => count+(kind.startsWith('history_') ? amount : 0), 0)
      current.max_parallel = Math.max(current.max_parallel, parallelHistory)
    }
  })
  page.on('requestfinished', finish); page.on('requestfailed', finish)
  return { start() { current = { topology: 0, history: 0, history_latest: 0, history_before: 0,
    history_after: 0, history_at: 0, max_parallel: 0 }; lastActivity = Date.now() },
    quiet: () => watched.size === 0 && Date.now()-lastActivity >= 500,
    stop() { const result = current; current = null; return result } }
}
