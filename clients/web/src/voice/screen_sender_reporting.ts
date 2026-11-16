import { watch, type Ref } from 'vue'

import { buildSenderScreenReport, startScreenClientReporting, webPlatform, type WebPlatform } from './screen_client_reporter'
import type { ScreenShareState } from './screen_controls'
import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenTelemetryPublicationScope } from './screen_sender_telemetry'

export function installScreenSenderReporting(
  state: Ref<ScreenShareState>,
  diagnostics: Ref<ScreenDiagnostics>,
  refresh: () => Promise<void>,
  platform: WebPlatform = webPlatform(navigator.userAgent),
  profile: () => string | null = () => null,
  readTelemetryScope: () => ScreenTelemetryPublicationScope | undefined = () => undefined,
): void {
  watch(state, (phase, _previous, onCleanup) => {
    if (phase !== 'SHARING') return
    void refresh()
    const stopReporting = startScreenClientReporting(
      () => buildSenderScreenReport(platform, diagnostics.value, profile()),
      () => true,
      readTelemetryScope,
      () => diagnostics.value,
    )
    const refreshTimer = globalThis.setInterval(() => { void refresh() }, 1000)
    onCleanup(() => { stopReporting(); globalThis.clearInterval(refreshTimer) })
  }, { immediate: true, flush: 'sync' })
}
