const origin = 'https://v.bootybay.ru'

async function read(request, path) {
  const response = await request(origin + path, { signal: AbortSignal.timeout(10000), redirect: 'error', cache: 'no-store' })
  if (!response.ok || new URL(response.url).origin !== origin) throw Error('Public endpoint unavailable')
  return response.json()
}

export async function publicRevision(request = fetch) {
  if ((await read(request, '/api/v1/health')).status !== 'ok') throw Error('API health failed')
  return (await read(request, '/release-receipt.json')).source_revision
}
