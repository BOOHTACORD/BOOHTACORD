import { screenTelemetryFreshnessMs, type ReceivedScreenTelemetry, type ScreenTelemetryMetricV1 } from './screen_receiver_telemetry'

export interface SenderTelemetryRow { label: string; value: string }
export interface SenderTelemetryPresentation {
  fresh: boolean
  freshness: string | null
  rows: SenderTelemetryRow[]
  platform: string | null
}

function numberText(value: number, maximumFractionDigits = 1): string {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits }).format(value)
}

function metricRow(label: string, metric: ScreenTelemetryMetricV1, unit: string, maximumFractionDigits = 1): SenderTelemetryRow | null {
  if (metric.value === undefined) return null
  const value = unit === 'Мбит/с' ? metric.value / 1_000_000 : metric.value
  const provenance = metric.provenance === 'configured' ? ' · задано' : ' · измерено'
  return { label, value: `${numberText(value, maximumFractionDigits)} ${unit}${provenance}` }
}

export function presentSenderTelemetry(sample: ReceivedScreenTelemetry | undefined, now = performance.now()): SenderTelemetryPresentation {
  if (!sample) return { fresh: false, freshness: null, rows: [], platform: null }
  const age = now - sample.receivedAtMonotonicMs
  if (age < 0 || age > screenTelemetryFreshnessMs) return { fresh: false, freshness: null, rows: [], platform: sample.envelope.platform }
  const envelope = sample.envelope
  const width = envelope.capture.width.value
  const height = envelope.capture.height.value
  const rows: (SenderTelemetryRow | null)[] = [
    width !== undefined && height !== undefined
      ? { label: 'Разрешение отправителя', value: `${Math.round(width)} × ${Math.round(height)} пикс. · ${envelope.capture.width.provenance === 'configured' || envelope.capture.height.provenance === 'configured' ? 'задано' : 'измерено'}` }
      : null,
    metricRow('FPS захвата отправителя', envelope.capture.fps, 'FPS'),
    metricRow('FPS кодирования отправителя', envelope.encode.fps, 'FPS'),
    metricRow('Битрейт отправителя', envelope.encode.bitrate_bps, 'Мбит/с'),
    metricRow('Потери пакетов у отправителя', envelope.transport.packet_loss_percent, '%', 2),
    metricRow('RTT отправителя', envelope.transport.rtt_ms, 'мс'),
    envelope.transport.quality_limitation_reason.value
      ? { label: 'Ограничение качества отправителя', value: envelope.transport.quality_limitation_reason.value }
      : null,
  ]
  return {
    fresh: true,
    freshness: (() => {
      const seconds = Math.max(0, Math.floor((now - sample.receivedAtMonotonicMs) / 1000))
      return seconds <= 1 ? 'Актуально только что' : `Актуально ${seconds} с назад`
    })(),
    rows: rows.filter((row): row is SenderTelemetryRow => row !== null),
    platform: envelope.platform,
  }
}
