<script setup lang="ts">
import { computed } from 'vue'

import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenProfile } from './livekit_gateway'
import { screenTargetLabel } from './screen_profile_metadata/presentation'
import { observedScreenCaptureTracks } from './screen_capture_capabilities'

const props = defineProps<{ diagnostics: ScreenDiagnostics; profile: ScreenProfile | null }>()
const emit = defineEmits<{ refresh: [] }>()

const target = computed(() => screenTargetLabel(props.profile ?? undefined))
const measured = computed(() => props.diagnostics.measured
  ? `${props.diagnostics.measured.width} × ${props.diagnostics.measured.height}${props.diagnostics.measured.framesPerSecond !== undefined ? ` · ${props.diagnostics.measured.framesPerSecond} FPS` : ''}`
  : 'нет данных от браузера/SDK')
const receivedTracks = computed(() => observedScreenCaptureTracks({
  videoTrack: props.diagnostics.source === 'UNKNOWN' ? null : props.diagnostics.source === 'ACTIVE',
  audioTrack: props.diagnostics.audioTrack === 'UNKNOWN' ? null : props.diagnostics.audioTrack === 'PRESENT',
}))
const audioTrack = computed(() => ({ present: 'есть', absent: 'нет', unknown: 'неизвестно' }[receivedTracks.value.audio]))
const videoTrack = computed(() => ({ present: 'есть', absent: 'нет', unknown: 'неизвестно' }[receivedTracks.value.video]))
const quality = computed(() => ({ EXCELLENT: 'отличное', GOOD: 'хорошее', POOR: 'низкое', LOST: 'потеряно', UNKNOWN: 'нет данных' }[props.diagnostics.connectionQuality]))
const source = computed(() => ({ ACTIVE: 'активен', ENDED: 'завершён', UNKNOWN: 'неизвестно' }[props.diagnostics.source]))
const layers = computed(() => (props.diagnostics.layers ?? []).map(layer => ({
  label: `${layer.rid ?? 'без RID'} · ${layer.codec ?? 'кодек неизвестен'} · ${layer.frameWidth ?? '?'} × ${layer.frameHeight ?? '?'}`,
  state: ({ ACTIVE: 'активен', INACTIVE: 'неактивен', STALE: 'устарел', UNKNOWN: 'нет данных' } as const)[layer.state],
  fps: layer.framesPerSecond === null ? 'нет данных' : `${layer.framesPerSecond.toFixed(1)} FPS`,
  bitrate: layer.bitrateBps === null ? 'нет данных' : `${Math.round(layer.bitrateBps / 1000)} кбит/с`,
  retransmitted: layer.retransmittedBps === null ? 'нет данных' : `${Math.round(layer.retransmittedBps / 1000)} кбит/с`,
  loss: layer.packetLossPercent === null ? 'нет данных' : `${layer.packetLossPercent.toFixed(2)}%`,
  control: `NACK ${layer.nackPerSecond?.toFixed(1) ?? '—'} · PLI ${layer.pliPerSecond?.toFixed(1) ?? '—'} · FIR ${layer.firPerSecond?.toFixed(1) ?? '—'}`,
  encode: layer.encodeMsPerFrame === null ? 'encode: нет данных' : `encode ${layer.encodeMsPerFrame.toFixed(2)} мс/кадр`,
})))
const technical = computed(() => [
  `Bitrate: ${props.diagnostics.bitrateBps === undefined ? 'нет данных' : `${Math.round(props.diagnostics.bitrateBps / 1000)} кбит/с`}`,
  `Потери: ${props.diagnostics.packetsLost ?? 'нет данных'}`,
  `RTT: ${props.diagnostics.roundTripTimeMs === undefined ? 'нет данных' : `${props.diagnostics.roundTripTimeMs} мс`}`,
  `Адаптация: ${props.diagnostics.adaptationReason ?? 'не сообщена'}`,
].join(' · '))
</script>

<template>
  <section class="screen-sender-summary" aria-label="Состояние отправителя">
    <p role="status">{{ diagnostics.source === 'ENDED' ? 'Демонстрация завершена.' : diagnostics.source === 'ACTIVE' ? 'Демонстрация идёт.' : 'Состояние источника неизвестно.' }}</p>
    <dl class="screen-diagnostics">
      <div><dt>Выбрано</dt><dd>{{ target }}</dd></div>
      <div><dt>Измерено отправителем</dt><dd>{{ measured }}</dd></div>
    </dl>
    <details class="screen-sender-details">
      <summary>Диагностика отправителя</summary>
      <dl class="screen-diagnostics">
        <div><dt>Фактически полученные дорожки</dt><dd>Видео: {{ videoTrack }} · Аудио: {{ audioTrack }}</dd></div>
        <div><dt>Качество связи</dt><dd>{{ quality }}</dd></div>
        <div><dt>Источник</dt><dd>{{ source }}</dd></div>
      </dl>
      <p>Голос остаётся доступен без аудиодорожки экрана.</p>
      <p>{{ technical }}</p>
      <details v-if="layers.length">
        <summary>Слои видеопотока</summary>
        <ul><li v-for="layer in layers" :key="layer.label">{{ layer.label }} · {{ layer.state }} · {{ layer.fps }} · {{ layer.bitrate }} · повторы {{ layer.retransmitted }} · потери {{ layer.loss }} · {{ layer.control }} · {{ layer.encode }}</li></ul>
      </details>
      <button class="voice-join" type="button" @click="emit('refresh')">Обновить измерения</button>
    </details>
  </section>
</template>
