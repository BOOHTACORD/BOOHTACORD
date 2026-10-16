<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenFrameRate, ScreenResolution } from './media_publishing'
import { screenShareBandwidthEstimate } from './screen_profile_metadata/profile'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import { containModalTab } from '../accessibility/modal_tab_focus'
import ScreenCaptureCapabilitySummary from './ScreenCaptureCapabilitySummary.vue'
import ScreenShareQualityOptions from './ScreenShareQualityOptions.vue'
import { normalizeScreenQualitySelection, selectScreenQualityMode, selectScreenQualityResolution } from './screen_share_quality_selection'
const props = defineProps<{ initialProfile: ScreenProfile; initialMode?: 'motion' | 'text'; updating?: boolean }>()
const emit = defineEmits<{ cancel: []; start: [profile: ScreenProfile, mode: 'motion' | 'text'] }>()
const dialog = ref<HTMLDialogElement | null>(null)
const opener = ref<HTMLElement | null>(null)
function profileValues(profile: ScreenProfile): { resolution: ScreenResolution; frameRate: ScreenFrameRate } | null {
  const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profile)
  if (!match) return null
  return { resolution: Number(match[1]) as ScreenResolution, frameRate: Number(match[2]) as ScreenFrameRate }
}
const initialValues = profileValues(props.initialProfile)
const initialSelection = initialValues
  ? normalizeScreenQualitySelection({ mode: props.initialMode ?? 'motion', ...initialValues })
  : null
const resolution = ref<ScreenResolution>(initialSelection?.resolution ?? 1080)
const frameRate = ref<ScreenFrameRate>(initialSelection?.frameRate ?? 30)
const mode = ref<'motion' | 'text'>(initialSelection?.mode ?? props.initialMode ?? 'motion')
const selectedProfile = computed(() => `P${resolution.value}_${frameRate.value}` as ScreenProfile)
const profileAllowed = computed(() => resolution.value !== 1440 || frameRate.value !== 60)
const bandwidthEstimate = computed(() => screenShareBandwidthEstimate(selectedProfile.value))
const profileSummary = computed(() => `${resolution.value}p · ${frameRate.value} FPS`)
const captureSupported = screenCaptureSupported()
const canStart = computed(() => profileAllowed.value && (props.updating || captureSupported))

function useProfile(profile: ScreenProfile): void {
  const values = profileValues(profile)
  if (!values) return
  const selection = normalizeScreenQualitySelection({ mode: mode.value, ...values })
  resolution.value = selection.resolution
  frameRate.value = selection.frameRate
  mode.value = selection.mode
}

function selectMode(value: 'motion' | 'text'): void {
  const selection = selectScreenQualityMode({ mode: mode.value, resolution: resolution.value, frameRate: frameRate.value }, value)
  mode.value = selection.mode
  resolution.value = selection.resolution
  frameRate.value = selection.frameRate
}

function selectResolution(value: ScreenResolution): void {
  const selection = selectScreenQualityResolution({ mode: mode.value, resolution: resolution.value, frameRate: frameRate.value }, value)
  mode.value = selection.mode
  resolution.value = selection.resolution
  frameRate.value = selection.frameRate
}

watch(() => props.initialProfile, useProfile)

onMounted(async () => {
  useProfile(props.initialProfile)
  opener.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
  await nextTick()
  if (dialog.value && !dialog.value.open) dialog.value.showModal()
  await nextTick()
  dialog.value?.querySelector<HTMLElement>('[autofocus]')?.focus()
})
onBeforeUnmount(() => {
  if (dialog.value?.open) dialog.value.close()
  void nextTick(() => {
    if (opener.value?.isConnected) opener.value.focus()
  })
})

function start(): void {
  if (canStart.value) emit('start', selectedProfile.value, mode.value)
}
</script>

<template>
  <dialog
    ref="dialog"
    class="screen-share-setup-dialog" :class="{ 'screen-share-setup-dialog--updating': updating }"
    aria-labelledby="screen-share-setup-title"
    :aria-describedby="updating ? 'screen-share-setup-description' : 'screen-share-setup-guidance'"
    @cancel.prevent="emit('cancel')"
    @keydown="containModalTab($event, dialog)"
  >
    <header class="screen-share-setup__header">
      <span v-if="!updating" class="screen-share-setup__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24"><path d="M3 4h18v13H3zM8 21h8m-4-4v4M8 12h3l2 2 4-5" /></svg>
      </span>
      <div class="screen-share-setup__title">
        <h2 id="screen-share-setup-title">{{ updating ? 'Качество трансляции' : 'Демонстрация экрана' }}</h2>
        <p v-if="updating" id="screen-share-setup-description">Изменения применятся к текущему показу.</p>
      </div>
      <button v-action-hint
        class="screen-share-setup__close"
        type="button"
        aria-label="Закрыть"
        title="Закрыть"
        autofocus
        @click="emit('cancel')"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>
      </button>
    </header>

    <div class="screen-share-setup__body">
      <p v-if="!updating && !captureSupported" class="state state-error" role="alert">{{ screenCaptureUnavailableMessage() }}</p>
      <section class="screen-share-quality" aria-labelledby="screen-share-quality-title">
        <h3 id="screen-share-quality-title" class="gc-sr-only">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h9m4 0h3M4 17h3m4 0h9M13 4v6M9 14v6" /></svg>
          Качество трансляции
        </h3>

        <ScreenShareQualityOptions
          :resolution="resolution"
          v-model:frame-rate="frameRate"
          :mode="mode"
          @update:resolution="selectResolution"
          @update:mode="selectMode"
        />
        <p class="screen-share-quality__current" role="status" aria-live="polite">Текущий выбор: {{ profileSummary }}</p>

        <p class="screen-share-quality__disclaimer">Профиль задаёт цель; фактическое качество зависит от источника, устройства и сети.</p>
      </section>

      <div v-if="!updating" id="screen-share-setup-guidance" class="screen-share-setup__notice" role="note">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 21 7v5c0 5-3.7 8-9 10-5.3-2-9-5-9-10V7zm0 5v5m0 3h.01" /></svg>
        <p>Источник выберете в окне браузера. Остановить показ можно в любой момент.</p>
      </div>

      <ScreenCaptureCapabilitySummary :bandwidth-estimate="bandwidthEstimate" :updating="updating" />
    </div>

    <footer class="screen-share-setup__footer">
      <button class="screen-share-setup__cancel" type="button" @click="emit('cancel')">Отмена</button>
      <button class="screen-share-setup__start" type="button" :disabled="!canStart" @click="start">
        <svg v-if="!updating" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4M12 8v6m-3-3 3-3 3 3" /></svg>
        {{ updating ? 'Применить' : 'Начать трансляцию' }}
      </button>
    </footer>
  </dialog>
</template>
