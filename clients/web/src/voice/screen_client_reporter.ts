import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { recordMediaSample } from '../telemetry/media_sample/record'
import { telemetrySession } from '../telemetry/action_scope/session'
import type { ScreenDiagnostics } from './screen_diagnostics'

export type { ScreenClientReport, ScreenClientReportInput, WebPlatform } from './report_media/types'
import type { ScreenClientReport, ScreenClientReportInput, WebPlatform } from './report_media/types'
import { senderMeasurements, receiverMeasurements } from './report_media/measurements'
import { bounded, pixelDimension, lossFields, sampleAge, senderFields } from './report_media/fields'
import { buildWebScreenTelemetryEnvelope, postScreenTelemetryEnvelope, type ScreenTelemetryPublicationScope } from './screen_sender_telemetry'

export function webPlatform(userAgent: string): WebPlatform {
  if (/iPhone|iPad|iPod/i.test(userAgent)) return 'ios_web'
  if (/Android/i.test(userAgent)) return 'android_web'
  return 'desktop_web'
}

export function buildScreenClientReport(input: ScreenClientReportInput): ScreenClientReport | null {
  if (input.sampledAt !== undefined && sampleAge(input.sampledAt) === undefined) return null
  if (!input.selected || (sampleAge(input.sampledAt) ?? 0) > 15000) return null
  const presented = input.presentationSource === 'unsupported' ? undefined : bounded(input.playbackFps, 240)
  const decoded = bounded(input.receiverMetrics?.decodedFps, 240)
  const bitrate = bounded(input.receiverMetrics?.bitrateKbps, 100000)
  const jitter = bounded(input.receiverMetrics?.jitterMs, 60000)
  const lost = bounded(input.receiverMetrics?.packetsLost, 1000000000)
  const dropped = bounded(input.receiverMetrics?.droppedFrames, 1000000000)
  const frameWidth = pixelDimension(input.frameWidth)
  const frameHeight = pixelDimension(input.frameHeight)
  const state = !input.hasTrack ? 'waiting_subscription' : !input.videoReady ? 'waiting_first_frame' : presented === 0 ? 'stalled' : 'playing'
  return {
    platform: input.platform, direction: 'receiver', state, ...receiverMeasurements(input),
    ...lossFields(input.receiverMetrics?.packetLossPercent, input.packetLossWindowMs ?? input.receiverMetrics?.packetLossWindowMs),
    ...(input.sampledAt === undefined ? {} : { sample_age_ms: sampleAge(input.sampledAt) }),
    ...(frameWidth === undefined || frameHeight === undefined ? {} : { frame_width: frameWidth, frame_height: frameHeight }),
    ...(presented === undefined ? {} : { presented_fps: presented }),
    ...(decoded === undefined ? {} : { decoded_fps: decoded }),
    ...(bitrate === undefined ? {} : { bitrate_kbps: bitrate }),
    ...(jitter === undefined ? {} : { jitter_ms: jitter }),
    ...(lost === undefined ? {} : { packets_lost: Math.floor(lost) }),
    ...(dropped === undefined ? {} : { dropped_frames: Math.floor(dropped) }),
  }
}

export function buildSenderScreenReport(platform: WebPlatform, diagnostics: ScreenDiagnostics, profile?: string | null): ScreenClientReport | null {
  if (diagnostics.sampledAt !== undefined && sampleAge(diagnostics.sampledAt) === undefined) return null
  if (diagnostics.source === 'ENDED' || (sampleAge(diagnostics.sampledAt) ?? 0) > 15000) return null
  if (diagnostics.senderStatsAvailable === false) return { platform, direction: 'sender', state: 'waiting_first_frame', ...senderFields(diagnostics, profile), ...senderMeasurements(diagnostics) }
  const encoded = bounded(diagnostics.measured?.framesPerSecond, 240)
  const bitrate = bounded(diagnostics.bitrateBps === undefined ? undefined : diagnostics.bitrateBps / 1000, 100000)
  const rtt = bounded(diagnostics.roundTripTimeMs, 60000)
  const frameWidth = diagnostics.senderDimensionsAvailable === false ? undefined : pixelDimension(diagnostics.measured?.width)
  const frameHeight = diagnostics.senderDimensionsAvailable === false ? undefined : pixelDimension(diagnostics.measured?.height)
  return {
    ...senderFields(diagnostics, profile), ...senderMeasurements(diagnostics),
    platform, direction: 'sender', state: diagnostics.source === 'ACTIVE' ? 'playing' : 'waiting_first_frame',
    ...(frameWidth === undefined || frameHeight === undefined ? {} : { frame_width: frameWidth, frame_height: frameHeight }),
    ...(encoded === undefined ? {} : { encoded_fps: encoded }),
    ...(bitrate === undefined ? {} : { bitrate_kbps: Math.round(bitrate * 10) / 10 }),
    ...(rtt === undefined ? {} : { rtt_ms: rtt }),
  }
}

export async function postScreenClientReport(report: ScreenClientReport, request: typeof fetch = tracedFetch, leaseId?: string): Promise<void> {
  const response = await request(`${apiBaseUrl}/voice/screen-metrics`, {
    method: 'POST', credentials: 'same-origin', headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify(leaseId ? { ...report, voice_lease_id: leaseId } : report),
  })
  if (!response.ok) throw new Error('screen metrics rejected')
}

export function startScreenClientReporting(
  read: () => ScreenClientReport | null,
  visible: () => boolean,
  readTelemetryScope: () => ScreenTelemetryPublicationScope | undefined = () => undefined,
  readScreenDiagnostics?: () => ScreenDiagnostics,
): () => void {
  const owner=telemetrySession.snapshot()
  let busy = false
  let telemetryBusy = false
  let sequence = 0
  const interval = globalThis.setInterval(() => {
    if (busy || !visible()) return
    const report = read()
    if (!report) return
    recordMediaSample({...report},owner)
    busy = true
    void postScreenClientReport(report, tracedFetch, owner.leaseId ?? undefined).catch(() => {}).finally(() => { busy = false })
    if (report.direction === 'sender' && owner.leaseId && readScreenDiagnostics && !telemetryBusy) {
      try {
        const scope = readTelemetryScope()
        if (scope?.ownerLeaseId === owner.leaseId) {
          const envelope = buildWebScreenTelemetryEnvelope({ scope, diagnostics: readScreenDiagnostics(), sequence: ++sequence, nowMs: Date.now() })
          if (envelope) {
            telemetryBusy = true
            void postScreenTelemetryEnvelope(owner.leaseId, envelope).catch(() => {}).finally(() => { telemetryBusy = false })
          }
        }
      } catch { /* A telemetry contract failure must not affect screen publishing. */ }
    }
  }, 5000)
  return () => globalThis.clearInterval(interval)
}
