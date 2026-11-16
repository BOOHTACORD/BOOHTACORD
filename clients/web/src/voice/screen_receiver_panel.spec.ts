import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

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
