<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { noiseSuppressionModeLabel, noiseSuppressionFallbackLabel } from './audio_processing_diagnostics'
import type { AudioProcessingOptions } from './noise_suppression/types'
import { playSpeakerCheck, startMicrophoneCheck, type MicrophoneCheck } from './audio_check'

const props = defineProps<{ inputId: string; outputId: string; processing: AudioProcessingOptions; connected: boolean; microphoneTrack?: MediaStreamTrack }>()
const level = ref(0)
const inputState = ref('Проверка микрофона выключена.')
const outputState = ref('')
const outputBusy = ref(false)
const inputBusy = ref(false)
let probe: MicrophoneCheck | null = null
let removeEndedListener: (() => void) | null = null
let timer: ReturnType<typeof setInterval> | null = null
let generation = 0

function stopInput(): void {
  generation++
  inputBusy.value = false
  if (timer) clearInterval(timer)
  timer = null
  removeEndedListener?.()
  removeEndedListener = null
  const old = probe
  probe = null
  level.value = 0
  inputState.value = 'Проверка микрофона выключена.'
  if (old) void old.stop()
}

function failInput(): void {
  generation++
  inputBusy.value = false
  if (timer) clearInterval(timer)
  timer = null
  removeEndedListener?.()
  removeEndedListener = null
  const old = probe
  probe = null
  level.value = 0
  inputState.value = 'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.'
  if (old) void old.stop()
}

async function toggleInput(): Promise<void> {
  if (inputBusy.value) return
  if (probe || timer) { stopInput(); return }
  const version = ++generation
  inputBusy.value = true
  inputState.value = 'Запрашиваем доступ к микрофону…'
  try {
    const started = await startMicrophoneCheck(props.inputId, undefined, undefined, { processing: props.processing, inCall: props.connected, borrowedTrack: props.connected ? props.microphoneTrack : undefined })
    if (version !== generation) { await started.stop(); return }
    probe = started
    removeEndedListener = started.onEnded(() => {
      if (version === generation) failInput()
    })
    const runtime = started.processingState?.()
    inputState.value = props.connected ? 'Индикатор показывает текущий выход микрофона звонка; состояние mute сохраняется.' : `Говорите: индикатор показывает локальный уровень. Выбрано: ${noiseSuppressionModeLabel(props.processing.noiseSuppressionMode)}; работает: ${noiseSuppressionModeLabel(runtime?.effectiveMode ?? 'unknown')}.${runtime?.fallbackReason ? ` Причина: ${noiseSuppressionFallbackLabel(runtime.fallbackReason)}.` : ''}`
    timer = setInterval(() => { level.value = started.level() }, 100)
  } catch (cause) {
    if (version === generation) inputState.value = cause instanceof Error ? cause.message : 'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.'
  } finally {
    if (version === generation) inputBusy.value = false
  }
}

async function checkOutput(): Promise<void> {
  if (outputBusy.value) return
  outputBusy.value = true
  outputState.value = 'Воспроизводим короткий сигнал…'
  try { await playSpeakerCheck(props.outputId); outputState.value = 'Сигнал завершён. Если его не было слышно, проверьте системную громкость и динамик.' }
  catch (cause) { outputState.value = cause instanceof Error ? cause.message : 'Не удалось воспроизвести сигнал.' }
  finally { outputBusy.value = false }
}

watch(() => props.inputId, stopInput)
watch(() => [props.processing, props.connected, props.microphoneTrack], stopInput)
onBeforeUnmount(stopInput)
</script>

<template>
  <section class="audio-device-check" aria-label="Проверка звука на этом устройстве">
    <div class="audio-level-row"><span>Уровень входа</span><div class="audio-level-meter" role="meter" aria-label="Уровень микрофона" aria-valuemin="0" aria-valuemax="100" :aria-valuenow="level"><i v-for="index in 28" :key="index" :class="{ active: index <= Math.round(level * 28 / 100) }" /></div></div>
    <div class="audio-device-check__actions">
      <button class="gc-button gc-button--secondary" type="button" :disabled="inputBusy" @click="toggleInput"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/></svg>{{ probe ? 'Остановить проверку микрофона' : 'Проверить микрофон' }}</button>
      <button class="gc-button gc-button--ghost" type="button" :disabled="outputBusy" @click="checkOutput"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m11 5-6 4H2v6h3l6 4V5ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14"/></svg>Тестовый звук</button>
    </div>
    <p v-if="probe || inputBusy || inputState !== 'Проверка микрофона выключена.'" role="status">{{ inputState }}</p>
    <p v-if="outputState" role="status">{{ outputState }}</p>
    <details class="audio-check-details"><summary>О проверке устройств</summary><p>Проверка локальная: она не подтверждает слышимость у другого участника.</p></details>
  </section>
</template>
