import type { Prepared, State } from './types'
import { uploadFailureMessage } from './failure'

export function drain<T extends Prepared>(state: State<T>): Promise<void> {
  if (state.running) return state.running
  const scope = state.scope(), version = state.version
  const current = () => version === state.version && scope === state.scope()
  state.running = (async () => {
    while (current()) {
      const item = state.items.value.find(entry => entry.status === 'queued')
      if (!item?.file) return
      const controller = new AbortController()
      state.active = controller
      item.status = 'uploading'; item.progress = 0; state.publish()
      try {
        const attachment = await state.upload(scope, item.file, { signal: controller.signal, onProgress: value => {
          if (current() && state.items.value.includes(item)) { item.progress = Math.min(99, Math.max(0, Math.round(value))); state.publish() }
        } })
        if (!current()) return
        if (state.items.value.includes(item)) { item.attachment = attachment; item.status = 'done'; item.progress = 100; item.file = undefined }
      } catch (cause) {
        if (!current()) return
        if (state.items.value.includes(item)) {
          item.status = 'failed'; item.error = uploadFailureMessage(cause)
          state.failed(cause)
        }
      } finally {
        if (current() && state.active === controller) state.active = null
      }
      if (current()) state.publish()
    }
  })().finally(() => { if (current()) { state.running = null; state.publish() } })
  return state.running
}
