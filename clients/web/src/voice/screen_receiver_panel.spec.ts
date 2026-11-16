import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { presentSenderTelemetry } from './screen_receiver_telemetry_presentation'

import ScreenReceiverDiagnosticsPanel from './ScreenReceiverDiagnosticsPanel.vue'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected screen receiver panel', () => {
  it('keeps the measured window beside packet loss and does not expose raw counters', async () => {
    const html = await renderToString(createSSRApp(ScreenReceiverDiagnosticsPanel, {
      actualVideoQuality: '1280 × 720 · 30 FPS', hasAudio: false, isLocal: false,
      metrics: { bitrateKbps: 500, decodedFps: 30, droppedFrames: 0, jitterMs: 2, packetsLost: 2476, packetLossPercent: 0.5, packetLossWindowMs: 10000, rttMs: null },
      sampledAt: 1000,
    }))
    expect(html).toContain('aria-label="Статистика"')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('metrics?.packetLossWindowMs')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('Потери пакетов ·')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('percentRow(packetLossLabel.value, metrics?.packetLossPercent)')
    expect(new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(0.5)).toBe('0,5')
    expect(html).not.toContain('>2476<')
  })

  it('formats fresh cross-platform sender measurements and drops them after expiry', () => {
    const monotonicReceivedAt = performance.now()
    const serverReceivedAt = new Date().toISOString()
    const sample = {
      ownerLeaseId: '11111111-1111-4111-8111-111111111111', serverReceivedAt, serverReceivedAtMs: Date.parse(serverReceivedAt), receivedAtMonotonicMs: monotonicReceivedAt,
      envelope: {
        schema_version: 1 as const, media_session_id: 'session-a', publication_generation: 2, platform: 'android' as const, client_kind: 'flutter' as const, capability_version: 1, sequence: 8,
        capture: {
          width: { value: 1920, availability: 'measured' as const, provenance: 'sender_measured' as const },
          height: { value: 1080, availability: 'measured' as const, provenance: 'sender_measured' as const },
          fps: { value: 30, availability: 'measured' as const, provenance: 'sender_measured' as const },
        },
        encode: {
          fps: { value: 29, availability: 'measured' as const, provenance: 'sender_measured' as const },
          bitrate_bps: { value: 4_000_000, availability: 'configured_only' as const, provenance: 'configured' as const },
        },
        transport: {
          packet_loss_percent: { availability: 'not_exposed' as const, provenance: 'unavailable' as const },
          rtt_ms: { availability: 'not_exposed' as const, provenance: 'unavailable' as const },
          quality_limitation_reason: { value: 'none', availability: 'measured' as const, provenance: 'sender_measured' as const },
        },
      },
    }
    const fresh = presentSenderTelemetry(sample, monotonicReceivedAt + 500)
    expect(fresh.freshness).toBe('Актуально только что')
    expect(fresh.rows).toContainEqual({ label: 'Разрешение отправителя', value: '1920 × 1080 пикс. · измерено' })
    expect(fresh.rows).toContainEqual({ label: 'Битрейт отправителя', value: '4 Мбит/с · задано' })
    expect(fresh.rows).not.toContainEqual(expect.objectContaining({ label: 'Потери пакетов у отправителя' }))
    expect(presentSenderTelemetry(sample, monotonicReceivedAt + 15_001).rows).toEqual([])
  })

  it('groups receiver, sender, configuration and unavailable diagnostics separately', () => {
    const viewer = source('./ScreenViewer.vue')
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    const styles = source('../design/voice_viewer_reference.css')
    const freshness = source('./screen_profile_metadata/profile.ts')
    const metadata = source('./screen_profile_metadata/presentation.ts')

    expect(viewer).toContain('<ScreenReceiverDiagnosticsPanel')
    expect(panel).toContain('<details ref="diagnostics" class="stream-diagnostics" @toggle="handleToggle">')
    expect(panel).toContain('screenSampleAge(null)')
    expect(freshness).toContain('Нет свежих данных')
    expect(panel).toContain('Декодирование')
    expect(panel).toContain('Показ кадров')
    expect(panel).toContain('Потери пакетов ·')
    expect(panel).toContain('packetLossPercent')
    expect(panel).toContain('screen-diagnostics-summary__group')
    expect(panel).toContain('Нет измерений от отправителя')
    expect(panel).not.toContain('Нет данных от приёмника')
    expect(panel).not.toContain('Возраст захвата неизвестен')
    expect(panel).toContain('screen-diagnostics-details')
    expect(panel).toContain('screen-diagnostics-unavailable')
    expect(metadata).toContain('Нет данных от отправителя')
    expect(metadata).toContain('Профиль при запуске · имя дорожки')
    expect(panel).toContain('Ограничения захвата')
    expect(panel).toContain('Ограничения кодирования')
    expect(panel).toContain("diagnostics?.selectedLayer?.state === 'ACTIVE' ? diagnostics.selectedLayer : undefined")
    expect(panel).toContain('Профиль из имени дорожки:')
    expect(styles).toContain('width: min(288px, calc(100vw - 32px))')
    expect(styles).toContain('font-variant-numeric: tabular-nums')
    expect(styles).toContain('.stream-diagnostics-panel { position: fixed;')
    expect(styles).toContain('overflow-y: auto')
    expect(panel).toContain('@toggle="handleToggle"')
    expect(panel).toContain('popover.style.top = `${result.top}px`')
    expect(panel).toContain('popover.style.left = `${result.left}px`')
    expect(panel).toContain('placeScreenDiagnostics')
    expect(source('../design/design_v2_stream_diagnostics.css')).toContain('height: min(514px, 80dvh)')
    expect(source('../design/design_v2_stream_diagnostics.css')).toContain('.screen-diagnostics-summary {')
  })

  it('returns focus to the trigger after closing the mobile statistics sheet', () => {
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    expect(panel).toContain('aria-modal')
    expect(panel).toContain("event.key === 'Escape'")
    expect(panel).toContain("querySelector('summary')?.focus()")
    expect(panel).toContain("querySelector<HTMLButtonElement>('header button')?.focus()")
  })
})
