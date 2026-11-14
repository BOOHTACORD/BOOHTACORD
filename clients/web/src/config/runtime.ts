const defaultApiBaseUrl = '/api/v1'

function normaliseApiBaseUrl(value: string | undefined): string {
  if (!value || !value.startsWith('/')) {
    return defaultApiBaseUrl
  }

  return value.replace(/\/+$/, '') || defaultApiBaseUrl
}

export const apiBaseUrl = normaliseApiBaseUrl(import.meta.env.VITE_API_BASE_URL)
export const apiV2BaseUrl = apiBaseUrl.replace(/\/v1$/, '/v2')
