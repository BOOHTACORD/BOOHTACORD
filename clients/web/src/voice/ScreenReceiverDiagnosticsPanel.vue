<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { containModalTab } from '../accessibility/modal_tab_focus'
import { placeScreenDiagnostics } from './screen_diagnostics_placement'
import type { ScreenReceiverMetrics } from './screen_receiver_diagnostics'
import { screenCaptureLabel, screenEncodingLabel, screenModeLabel, screenTargetLabel, screenTargetSourceLabel, screenDescriptorStatusLabel, screenDescriptorProvenanceLabel, screenDescriptorReceivedAge, type ScreenProfileSource } from './screen_profile_metadata/presentation'
import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenShareDescriptorV1 } from './screen_profile_metadata/types'
import { screenSampleAge } from './screen_profile_metadata/profile'

interface DiagnosticRow { label: string; value: string }
interface UnavailableRow { label: string; reason: string }

const props = defineProps<{
  actualVideoQuality: string
  hasAudio: boolean
  isLocal: boolean
  metrics: ScreenReceiverMetrics | null
  sampledAt: number | null
  targetProfile?: string
  descriptor?: ScreenShareDescriptorV1
  profileSource?: ScreenProfileSource
  participantName?: string
  presentedFps?: number | null
  metadataReceiptKey?: string
  senderDiagnostics?: ScreenDiagnostics
}>()
const receivedAt = ref<number | null>(null)
const now = ref(Date.now())
let ageTimer: ReturnType<typeof setInterval> | undefined
watch(() => [props.metadataReceiptKey, props.descriptor] as const, () => {
  receivedAt.value = props.descriptor ? Date.now() : null
}, { immediate: true })
const descriptorStatus = computed(() => screenDescriptorStatusLabel(props.descriptor))
const descriptorProvenance = computed(() => screenDescriptorProvenanceLabel(props.descriptor))
const descriptorAge = computed(() => screenDescriptorReceivedAge(receivedAt.value, now.value))
const target = computed(() => screenTargetLabel(props.descriptor?.requested_profile_id, props.targetProfile))
const targetSummary = computed(() => {
  if (!target.value || target.value.startsWith('Нет данных')) return null
  return props.profileSource === 'legacy-track-name'
    ? `Профиль из имени дорожки: ${target.value}`
    : `Цель: ${target.value}`
})
const sourceLabel = computed(() => screenTargetSourceLabel(props.profileSource))
const mode = computed(() => props.descriptor ? screenModeLabel(props.descriptor.mode) : null)
const capture = computed(() => props.descriptor ? screenCaptureLabel(props.descriptor) : null)
const encoding = computed(() => props.descriptor ? screenEncodingLabel(props.descriptor) : null)
const sampledStatus = computed(() => props.sampledAt === null
  ? screenSampleAge(null)
  : `${new Date(props.sampledAt).toLocaleTimeString('ru-RU')} · ${screenSampleAge(props.sampledAt)}`)
const diagnostics = ref<HTMLDetailsElement | null>(null)
const isOpen = ref(false)
const teleportTarget = ref<string | Element>('body')
const copyFeedback = ref('')

function finiteNonNegative(value: number | null | undefined): value is number {
  return value !== null && value !== undefined && Number.isFinite(value) && value >= 0
}

function numberText(value: number, maximumFractionDigits = 1): string {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits }).format(value)
}

function metricRow(label: string, value: number | null | undefined, unit: string, maximumFractionDigits = 1): DiagnosticRow | null {
  return finiteNonNegative(value) ? { label, value: `${numberText(value, maximumFractionDigits)} ${unit}` } : null
}

function percentRow(label: string, value: number | null | undefined): DiagnosticRow | null {
  return finiteNonNegative(value) ? { label, value: `${numberText(value, 2)} %` } : null
}

function measuredVideoQuality(): string | null {
  return /^\d+\s*×\s*\d+/.test(props.actualVideoQuality) ? props.actualVideoQuality : null
}

const packetLossLabel = computed(() => {
  const windowMs = props.metrics?.packetLossWindowMs
  return finiteNonNegative(windowMs) && windowMs > 0
    ? `Потери пакетов · ${numberText(windowMs / 1000, 1)} с`
    : 'Потери пакетов'
})
const receiverSummaryRows = computed<DiagnosticRow[]>(() => {
  const metrics = props.metrics
  const rows: (DiagnosticRow | null)[] = [
    measuredVideoQuality() ? { label: 'Видео у вас', value: measuredVideoQuality()! } : null,
    metricRow('Декодирование', metrics?.decodedFps, 'FPS'),
    metricRow('Показ кадров', props.presentedFps, 'FPS'),
    metrics?.bitrateKbps == null ? null : metricRow('Битрейт', metrics.bitrateKbps / 1000, 'Мбит/с'),
    percentRow(packetLossLabel.value, metrics?.packetLossPercent),
    metricRow('Джиттер', metrics?.jitterMs, 'мс'),
    metricRow('RTT', metrics?.rttMs, 'мс'),
  ]
  return rows.filter((row): row is DiagnosticRow => row !== null)
})
const receiverTechnicalRows = computed<DiagnosticRow[]>(() => {
  const metrics = props.metrics
  const rows: (DiagnosticRow | null)[] = [
    ...receiverSummaryRows.value,
    metricRow('Отброшено кадров за выборку', metrics?.droppedFrames, 'кадров', 0),
    metricRow('Задержка декодирования на кадр', metrics?.decodeMsPerFrame, 'мс'),
    metricRow('Задержка jitter buffer на кадр', metrics?.jitterBufferMsPerFrame, 'мс'),
    metricRow('NACK', metrics?.nackPerSecond, 'в секунду'),
    metricRow('PLI', metrics?.pliPerSecond, 'в секунду'),
    metricRow('FIR', metrics?.firPerSecond, 'в секунду'),
    metricRow('Замирания', metrics?.freezeCount, 'раз', 0),
    metricRow('Длительность замираний', metrics?.freezeDurationMs, 'мс'),
  ]
  return rows.filter((row, index, all): row is DiagnosticRow => row !== null && all.findIndex(other => other?.label === row.label) === index)
})

const senderRows = computed<DiagnosticRow[]>(() => {
  const diagnostics = props.senderDiagnostics
  const layer = diagnostics?.selectedLayer?.state === 'ACTIVE' ? diagnostics.selectedLayer : undefined
  const rows: (DiagnosticRow | null)[] = []
  const width = layer?.frameWidth
  const height = layer?.frameHeight
  if (finiteNonNegative(width) && width > 0 && finiteNonNegative(height) && height > 0) {
    rows.push({ label: 'Разрешение отправителя', value: `${Math.round(width)} × ${Math.round(height)} пикс.` })
  }
  rows.push(metricRow('FPS отправителя', layer?.framesPerSecond, 'FPS'))
  rows.push(layer?.bitrateBps == null ? null : metricRow('Битрейт отправителя', layer.bitrateBps / 1_000_000, 'Мбит/с'))
  rows.push(percentRow('Потери пакетов у отправителя', layer?.packetLossPercent))
  rows.push(metricRow('RTT отправителя', layer?.roundTripTimeMs, 'мс'))
  return rows.filter((row): row is DiagnosticRow => row !== null)
})

const senderSummaryRows = computed<DiagnosticRow[]>(() => senderRows.value.slice(0, 2))
const configurationRows = computed<DiagnosticRow[]>(() => {
  const rows: DiagnosticRow[] = []
  if (targetSummary.value) rows.push({ label: 'Профиль', value: targetSummary.value })
  if (props.profileSource && props.profileSource !== 'unknown') rows.push({ label: 'Источник цели', value: sourceLabel.value })
  rows.push({ label: 'Состояние публикации', value: descriptorStatus.value })
  if (props.descriptor) {
    rows.push({ label: 'Источник конфигурации', value: descriptorProvenance.value })
    rows.push({ label: 'Получение конфигурации', value: descriptorAge.value })
    if (mode.value) rows.push({ label: 'Сценарий', value: mode.value })
    if (capture.value) rows.push({ label: 'Ограничения захвата', value: capture.value })
    if (encoding.value) rows.push({ label: 'Ограничения кодирования', value: encoding.value })
  }
  return rows
})
const unavailableRows = computed<UnavailableRow[]>(() => {
  const rows: UnavailableRow[] = []
  if (!props.metrics) rows.push({ label: 'Приёмник', reason: 'Статистика выбранного видео receiver ещё не получена.' })
  else {
    if (props.metrics.packetLossPercent == null) rows.push({ label: 'Потери пакетов', reason: 'Нет валидного окна дельт received/lost.' })
    if (props.metrics.rttMs == null) rows.push({ label: 'RTT', reason: 'Текущая статистика не содержит RTT для единственного выбранного WebRTC пути.' })
  }
  if (senderRows.value.length === 0) rows.push({ label: 'Фактические измерения отправителя', reason: 'Текущий viewer не получил измерения отправителя.' })
  if (!targetSummary.value) rows.push({ label: 'Целевой профиль', reason: 'Профиль не передан отправителем.' })
  rows.push({ label: 'Возраст захвата', reason: 'Отправитель не передаёт сопоставимое измерение capture-age.' })
  return rows
})

async function copyStatistics(): Promise<void> {
  // Explicit, content-free export: no participant name, source title, IDs or addresses.
  const rows = [
    ['Источник', 'Статистика выбранной демонстрации'],
    ...receiverTechnicalRows.value.map(row => [row.label, row.value]),
    ...senderRows.value.map(row => [row.label, row.value]),
    ...configurationRows.value.map(row => [row.label, row.value]),
    ...unavailableRows.value.map(row => [row.label, row.reason]),
  ]
  try {
    await navigator.clipboard.writeText(rows.map(row => row.join(': ')).join('\n'))
    copyFeedback.value = 'Статистика скопирована'
  } catch { copyFeedback.value = 'Не удалось скопировать статистику. Разрешите доступ к буферу обмена и повторите.' }
  void nextTick(updatePlacement)
}

const mobile = ref(false)
const panel = ref<HTMLDivElement | null>(null)
let placementFrame = 0

function updatePlacement(): void {
  const root = diagnostics.value
  if (!root?.open) return
  cancelAnimationFrame(placementFrame)
  placementFrame = requestAnimationFrame(() => {
    const popover = panel.value
    if (!popover) return
    const summary = root.querySelector('summary')
    if (!summary || !root.open) return
    const rect = summary.getBoundingClientRect()
    const result = placeScreenDiagnostics({
      summaryLeft: rect.left,
      summaryRight: rect.right,
      summaryTop: rect.top,
      summaryBottom: rect.bottom,
      panelHeight: popover.scrollHeight,
      panelWidth: popover.getBoundingClientRect().width,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
      alignLeft: window.innerWidth <= 1100,
    })
    root.dataset.placement = result.placement
    popover.style.maxHeight = `${result.maxHeight}px`
    popover.style.top = `${result.top}px`
    popover.style.left = `${result.left}px`
  })
}
function close(): void {
  if (diagnostics.value) diagnostics.value.open = false
  isOpen.value = false
  clearInterval(ageTimer); ageTimer = undefined
  diagnostics.value?.querySelector('summary')?.focus()
}
function handleToggle(): void {
  teleportTarget.value = document.fullscreenElement ?? 'body'
  isOpen.value = Boolean(diagnostics.value?.open)
  clearInterval(ageTimer); ageTimer = undefined
  if (isOpen.value) {
    copyFeedback.value = ''
    now.value = Date.now()
    ageTimer = setInterval(() => { now.value = Date.now() }, 1000)
  }
  if (isOpen.value) void nextTick(() => panel.value?.querySelector<HTMLButtonElement>('header button')?.focus())
  updatePlacement()
}
function handleKeydown(event: KeyboardEvent): void {
  if (!isOpen.value) return
  if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); close() }
  else if (mobile.value && event.key === 'Tab') {
    containModalTab(event, panel.value)
    ;(document.activeElement as HTMLElement | null)?.scrollIntoView({ block: 'nearest' })
  }
}
function handleResize(): void { mobile.value = window.innerWidth <= 600; updatePlacement() }

onMounted(() => {
  handleResize()
  window.addEventListener('resize', handleResize)
  window.addEventListener('scroll', updatePlacement, true)
  window.addEventListener('keydown', handleKeydown, true)
})
onBeforeUnmount(() => {
  clearInterval(ageTimer)
  cancelAnimationFrame(placementFrame)
  window.removeEventListener('resize', handleResize)
  window.removeEventListener('scroll', updatePlacement, true)
  window.removeEventListener('keydown', handleKeydown, true)
})
</script>

<template>
  <details ref="diagnostics" class="stream-diagnostics" @toggle="handleToggle">
    <summary :title="sampledStatus" aria-label="Статистика" class="stream-tool-button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V4M4 20h17M8 16v-5M13 16V7M18 16v-9"/></svg><span class="gc-sr-only">Статистика</span></summary>
    <Teleport v-if="isOpen" :to="teleportTarget">
      <button type="button" class="stream-diagnostics-backdrop" aria-label="Закрыть статистику" @click="close" />
      <div ref="panel" class="stream-diagnostics-panel" role="dialog" aria-label="Статистика трансляции" :aria-modal="mobile ? 'true' : undefined">
        <header><h2>Статистика</h2><button type="button" aria-label="Закрыть статистику" @click="close">×</button></header>
        <p>{{ participantName ? `Экран ${participantName}` : 'Трансляция' }} · {{ sampledStatus }}</p>

        <div class="screen-diagnostics-summary">
          <section class="screen-diagnostics-summary__group" aria-labelledby="screen-summary-receiver">
            <h3 id="screen-summary-receiver">У вас</h3>
            <dl v-if="receiverSummaryRows.length">
              <div v-for="row in receiverSummaryRows" :key="row.label"><dt>{{ row.label }}</dt><dd>{{ row.value }}</dd></div>
            </dl>
            <p v-else>Пока нет измерений приёма.</p>
          </section>
          <section class="screen-diagnostics-summary__group" aria-labelledby="screen-summary-sender">
            <h3 id="screen-summary-sender">Отправитель</h3>
            <p v-if="targetSummary" class="screen-diagnostics-target">{{ targetSummary }}</p>
            <dl v-if="senderSummaryRows.length">
              <div v-for="row in senderSummaryRows" :key="row.label"><dt>{{ row.label }}</dt><dd>{{ row.value }}</dd></div>
            </dl>
            <p v-else>Нет измерений от отправителя.</p>
          </section>
        </div>

        <details class="stream-diagnostics-technical" @toggle="updatePlacement">
          <summary>Диагностика</summary>
          <div class="screen-diagnostics-details">
            <section aria-labelledby="screen-diagnostics-receiver">
              <h3 id="screen-diagnostics-receiver">Приёмник</h3>
              <p>Актуальность: {{ sampledStatus }}</p>
              <dl v-if="receiverTechnicalRows.length">
                <div v-for="row in receiverTechnicalRows" :key="row.label"><dt>{{ row.label }}</dt><dd>{{ row.value }}</dd></div>
              </dl>
              <p v-else>Нет текущих измерений приёма.</p>
            </section>
            <section aria-labelledby="screen-diagnostics-sender">
              <h3 id="screen-diagnostics-sender">Отправитель</h3>
              <dl v-if="senderRows.length">
                <div v-for="row in senderRows" :key="row.label"><dt>{{ row.label }}</dt><dd>{{ row.value }}</dd></div>
              </dl>
              <p v-else>Нет измерений от отправителя.</p>
            </section>
            <section aria-labelledby="screen-diagnostics-config">
              <h3 id="screen-diagnostics-config">Конфигурация</h3>
              <dl v-if="configurationRows.length">
                <div v-for="row in configurationRows" :key="row.label"><dt>{{ row.label }}</dt><dd>{{ row.value }}</dd></div>
              </dl>
              <p v-else>Конфигурация отправителя не подтверждена.</p>
            </section>
            <section v-if="unavailableRows.length" aria-labelledby="screen-diagnostics-unavailable">
              <h3 id="screen-diagnostics-unavailable">Недоступно</h3>
              <ul><li v-for="row in unavailableRows" :key="row.label"><strong>{{ row.label }}:</strong> {{ row.reason }}</li></ul>
            </section>
          </div>
        </details>

        <button class="stream-diagnostics-copy" type="button" @click="copyStatistics">Копировать статистику</button>
        <p v-if="copyFeedback" role="status">{{ copyFeedback }}</p>
      </div>
    </Teleport>
  </details>
</template>
