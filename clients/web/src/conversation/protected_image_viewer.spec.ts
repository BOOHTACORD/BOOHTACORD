import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useProtectedImagePreview } from './protected_image_preview/use_protected_image_preview'

const lifecycle = vi.hoisted(() => ({ unmount: () => {} }))
vi.mock('vue', async () => ({
  ...await vi.importActual<typeof import('vue')>('vue'),
  onBeforeUnmount: (callback: () => void) => { lifecycle.unmount = callback },
}))
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>(complete => { resolve = complete })
  return { promise, resolve }
}
const response = () => new Response('normalized PNG fixture', { headers: { 'content-type': 'image/png' } })

describe('protected image preview lifecycle', () => {
  beforeEach(() => {
    vi.spyOn(URL, 'createObjectURL').mockReturnValue('blob:private-preview')
    vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})
  })
  afterEach(() => { lifecycle.unmount(); vi.unstubAllGlobals(); vi.restoreAllMocks() })

  it('loads only the credentialed no-store preview and revokes it on close', async () => {
    const fetcher = vi.fn().mockResolvedValue(response()); vi.stubGlobal('fetch', fetcher)
    const owner = useProtectedImagePreview(() => '/api/v1/channels/a/attachments/b/preview', () => true)
    await owner.loadPreview()
    expect(owner.imageUrl.value).toBe('blob:private-preview')
    expect(fetcher).toHaveBeenCalledWith('/api/v1/channels/a/attachments/b/preview', expect.objectContaining({ credentials: 'same-origin', cache: 'no-store' }))
    owner.cancelPreview()
    expect(owner.imageUrl.value).toBeNull()
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:private-preview')
  })

  it('aborts a closed request and rejects late bytes independently of transport cancellation', async () => {
    const pending = deferred<Response>(), fetcher = vi.fn().mockReturnValue(pending.promise)
    vi.stubGlobal('fetch', fetcher)
    const owner = useProtectedImagePreview(() => '/private/preview', () => true)
    const loading = owner.loadPreview()
    const signal = fetcher.mock.calls[0][1].signal as AbortSignal | undefined
    owner.cancelPreview(); pending.resolve(response()); await loading
    expect(owner.imageUrl.value).toBeNull()
    expect(URL.createObjectURL).not.toHaveBeenCalled()
    expect(signal?.aborted).toBe(true)
  })

  it('cannot let an obsolete 404 poison a newer successful preview', async () => {
    const old = deferred<Response>(), fetcher = vi.fn().mockReturnValueOnce(old.promise).mockResolvedValueOnce(response())
    vi.stubGlobal('fetch', fetcher)
    const owner = useProtectedImagePreview(() => '/private/preview', () => true)
    const previous = owner.loadPreview()
    await owner.loadPreview()
    old.resolve(new Response('', { status: 404 })); await previous
    expect(owner.imageUrl.value).toBe('blob:private-preview')
    expect(owner.failed.value).toBe(false)
    expect(owner.unavailable.value).toBe(false)
  })

  it('does not start a request when the viewer is closed', async () => {
    const fetcher = vi.fn().mockResolvedValue(response()); vi.stubGlobal('fetch', fetcher)
    const owner = useProtectedImagePreview(() => '/private/preview', () => false)
    await owner.loadPreview()
    expect(fetcher).not.toHaveBeenCalled()
    expect(owner.loading.value).toBe(false)
  })

  it('unmount retires work and disallows subsequent obsolete callbacks', async () => {
    const pending = deferred<Response>(), fetcher = vi.fn().mockReturnValue(pending.promise)
    vi.stubGlobal('fetch', fetcher)
    const owner = useProtectedImagePreview(() => '/private/preview', () => true)
    const loading = owner.loadPreview(); lifecycle.unmount()
    pending.resolve(response()); await loading
    await owner.loadPreview()
    expect(owner.imageUrl.value).toBeNull()
    expect(fetcher).toHaveBeenCalledTimes(1)
  })
})
