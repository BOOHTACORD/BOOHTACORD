const accept = 'application/vnd.github+json'
const requestTimeoutMs = 15 * 60 * 1000
export const maxAttempts = 3

export class GitHubApiError extends Error {
  constructor(status, method, url) {
    super(`GitHub API ${method} failed with HTTP ${status}`)
    this.name = 'GitHubApiError'
    this.status = status
    this.url = url
  }
}

export function isRetryable(error) {
  return !(error instanceof GitHubApiError) ||
    [408, 425, 429].includes(error.status) ||
    error.status >= 500
}

export function retryDelay(attempt) {
  return Math.min(1_000 * (2 ** (attempt - 1)), 8_000)
}

export function apiUrl(apiRoot, pathname) {
  return `${apiRoot.replace(/\/$/, '')}${pathname}`
}

export async function sendJson({ fetchImpl, token, url, method = 'GET', body }) {
  const isBinary = body instanceof Uint8Array
  const response = await fetchImpl(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: accept,
      ...(body == null ? {} : { 'Content-Type': isBinary ? 'application/octet-stream' : 'application/json' }),
    },
    ...(body == null ? {} : { body: isBinary ? body : JSON.stringify(body) }),
    signal: AbortSignal.timeout(requestTimeoutMs),
    redirect: 'error',
  })

  if (!response.ok) throw new GitHubApiError(response.status, method, url)
  if (response.status === 204) return null
  return response.json()
}
