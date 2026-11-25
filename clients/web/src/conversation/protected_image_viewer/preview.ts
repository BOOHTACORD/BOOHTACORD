import { onBeforeUnmount, ref } from 'vue'

export function useProtectedImagePreview(previewUrl: () => string, isOpen: () => boolean) {
  const imageUrl = ref<string | null>(null)
  const loading = ref(false), unavailable = ref(false), failed = ref(false)
  let requestRevision = 0, disposed = false
  let objectUrl: string | null = null
  let request: AbortController | null = null

  function revokePreview(): void {
    if (objectUrl) URL.revokeObjectURL(objectUrl)
    objectUrl = null; imageUrl.value = null
  }
  async function loadPreview(): Promise<void> {
    if (disposed || !isOpen()) return
    const revision = ++requestRevision, source = previewUrl()
    request?.abort()
    const activeRequest = new AbortController()
    request = activeRequest
    revokePreview()
    loading.value = true; unavailable.value = false; failed.value = false
    const current = () => !disposed && revision === requestRevision && isOpen() && source === previewUrl()
    try {
      const response = await fetch(source, {
        credentials: 'same-origin', cache: 'no-store', headers: { accept: 'image/png' },
        signal: activeRequest.signal,
      })
      if (!current()) return
      if (!response.ok) {
        unavailable.value = response.status === 404 || response.status === 410
        throw new Error('preview unavailable')
      }
      const blob = await response.blob()
      if (!current()) return
      objectUrl = URL.createObjectURL(blob)
      imageUrl.value = objectUrl
    } catch {
      if (current()) failed.value = true
    } finally {
      if (revision === requestRevision) { loading.value = false; request = null }
    }
  }
  function cancelPreview(): void {
    requestRevision++
    request?.abort(); request = null
    loading.value = false
    revokePreview()
  }
  onBeforeUnmount(() => { disposed = true; cancelPreview() })
  return { imageUrl, loading, unavailable, failed, loadPreview, cancelPreview }
}
