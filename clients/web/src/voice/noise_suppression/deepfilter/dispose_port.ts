/** Acknowledge WASM state destruction before releasing the message channel. */
export async function disposePort(port: MessagePort, timeoutMs: number): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    await new Promise<void>((resolve, reject) => {
      timer = setTimeout(() => reject(new Error('processor disposal timeout')), timeoutMs)
      port.onmessage = event => {
        if (event.data.type === 'destroyed') resolve()
        else if (event.data.type === 'error') reject(new Error('processor disposal failed'))
      }
      port.postMessage({ type: 'destroy' })
    })
  } finally {
    if (timer !== undefined) clearTimeout(timer)
    port.onmessage = null; port.close()
  }
}
