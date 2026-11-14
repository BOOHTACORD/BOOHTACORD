export interface RealtimeSocket {
  readonly protocol?: string
  close(): void
  send?(data: string): void
  onclose: ((event: CloseEvent) => void) | null
  onerror: ((event: Event) => void) | null
  onmessage: ((event: MessageEvent<string>) => void) | null
  onopen: ((event: Event) => void) | null
}

export type RealtimeSocketFactory = (url: string) => RealtimeSocket

export interface RealtimeConnectOptions {
  onHintBatch?: import('./hint_batch/controller').HintBatchHandler
  checkSession?: (signal: AbortSignal) => Promise<boolean>
  onRecovery?: () => void | Promise<void>
  onSessionExpired?: () => void
  onSocketStart?: () => void
  onSocketEnd?: () => void
  random?: () => number
}
