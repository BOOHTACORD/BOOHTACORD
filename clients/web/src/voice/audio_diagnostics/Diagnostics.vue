<script setup lang="ts">
import { computed, ref } from 'vue'
import { voiceAudioProfiles } from '../audio_profile/generated'
import { selectedVoiceAudioProfile, selectVoiceAudioProfile } from '../audio_profile/profile'
import { exportVoiceAudioDiagnostics, type VoiceAudioDiagnostics } from './model'
const props = defineProps<{ connected: boolean; diagnostics?: VoiceAudioDiagnostics | null }>()
const selected = ref(selectedVoiceAudioProfile().id)
const exported = ref(false)
function choose(event: Event): void {
  const id = (event.target as HTMLSelectElement).value
  if (!props.connected && selectVoiceAudioProfile(id)) selected.value = selectedVoiceAudioProfile().id
}
const text = computed(() => props.diagnostics ? exportVoiceAudioDiagnostics(props.diagnostics) : '')
const metric = (value: number | null | undefined, unit = '') => value == null ? 'неизвестно' : `${Math.round(value * 100) / 100}${unit}`
const flag = (value: boolean | null) => value === null ? 'неизвестно' : value ? 'да' : 'нет'
</script>
<template>
  <details class="audio-processing-details">
    <summary>Диагностика качества голоса</summary>
    <label>Профиль следующего подключения<select class="gc-field" :value="selected" :disabled="connected" @change="choose"><option v-for="profile in voiceAudioProfiles" :key="profile.id" :value="profile.id">{{ profile.maxBitrate / 1000 }} кбит/с — {{ profile.id }}</option></select></label>
    <p>64 и 96 кбит/с — кандидаты для A/B. Улучшение качества ещё не подтверждено.</p>
    <p>Запрошено: Opus, mono, 48 кГц, высокий приоритет, DTX и RED. Фактические параметры — ниже.</p>
    <template v-if="diagnostics">
      <p>Текущий профиль: {{ diagnostics.profile }}; предел {{ diagnostics.capBps / 1000 }} кбит/с.</p>
      <p>Исходный capture: {{ metric(diagnostics.capture.sampleRate, ' Гц') }}, {{ metric(diagnostics.capture.channels, ' каналов') }}. AGC {{ flag(diagnostics.capture.agc) }}, AEC {{ flag(diagnostics.capture.aec) }}, NS {{ flag(diagnostics.capture.ns) }}.</p>
      <p>Каналы RTP Opus не доказывают стерео capture. Неизвестные flags не подменяются запрошенными.</p>
      <p>DTX, FEC и stereo показывают параметры SDP, а не использование в каждом пакете. Opus в статистике не исключает RED; RTP bitrate может включать избыточные данные.</p>
      <p v-if="!diagnostics.samples.length">SDK не сообщил RTP-статистику микрофона.</p>
      <section v-for="(sample, index) in diagnostics.samples" :key="index">
        <h3>{{ sample.direction === 'sender' ? 'Отправка' : 'Приём' }} {{ index + 1 }}</h3>
        <p v-if="sample.codec !== null && sample.codec !== 'opus'" role="status">Codec отличается от запрошенного Opus.</p>
        <p>Интервал измерения: {{ metric(sample.intervalMs, ' мс') }}</p>
        <p>Codec {{ sample.codec ?? 'неизвестно' }} / RTP {{ sample.transportCodec ?? 'неизвестно' }}, {{ metric(sample.clockRate, ' Гц') }}, {{ metric(sample.codecChannels, ' RTP каналов') }}; stereo {{ flag(sample.stereo) }}, DTX {{ flag(sample.dtx) }}, RED {{ flag(sample.red) }}, FEC {{ flag(sample.fec) }}.</p>
        <p>{{ metric(sample.bitrateBps == null ? null : sample.bitrateBps / 1000, ' кбит/с') }}; пакеты {{ metric(sample.packets) }}; jitter {{ metric(sample.jitterMs, ' мс') }}; loss {{ metric(sample.lossPercent, '%') }}; concealment {{ metric(sample.concealedSamples) }} samples / {{ metric(sample.concealmentEvents) }} events за интервал.</p>
        <p>Уровень (только локально): {{ metric(sample.audioLevel) }}</p>
      </section>
      <button class="gc-button gc-button--secondary" type="button" @click="exported = !exported">Показать безопасный отчёт для A/B</button>
      <textarea v-if="exported" class="gc-field" aria-label="Отчёт без идентификаторов и уровней" readonly :value="text" rows="12" style="width: 100%" />
    </template>
    <p v-else>Статистика появляется после подключения и двух измерений. На неподдерживаемой платформе остаётся неизвестной.</p>
  </details>
</template>
