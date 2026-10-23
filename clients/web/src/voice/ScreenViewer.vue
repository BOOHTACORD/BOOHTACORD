<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { participantAudioMessage, screenAudioMessage } from './screen_audio_copy'
import ScreenMiniToolbar from './ScreenMiniToolbar.vue'
import ScreenViewerAudioControl from './ScreenViewerAudioControl.vue'
import ScreenViewerRail from './ScreenViewerRail.vue'
import ScreenViewerParticipantStrip from './ScreenViewerParticipantStrip.vue'
import ScreenReceiverDiagnosticsPanel from './ScreenReceiverDiagnosticsPanel.vue'
import DiagnosisPanel from './viewer_diagnosis/Panel.vue'
import type { ScreenDiagnostics } from './screen_diagnostics'
import { markScreenSelected } from '../telemetry/journey_intervals/runtime'
import type { ScreenViewerCard } from './screen_viewer_controller'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import { createScreenFullscreenControls } from './screen_fullscreen_controls'
import { useScreenPlaybackQuality } from './screen_playback_quality'
import { useScreenReceiverDiagnostics } from './use_screen_receiver_diagnostics'
import { buildScreenClientReport, startScreenClientReporting, webPlatform } from './screen_client_reporter'
const props = withDefaults(defineProps<{ audioMuted: boolean; cards: ScreenViewerCard[]; deafened: boolean; ended: boolean; error: string | null; expanded: boolean; mini?: boolean; ownScreenSharing?: boolean; participants: VoiceVolumeParticipant[]; screenWatcherIds?: string[]; selfAccountId?: string; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfName: string | null; selfSpeaking: boolean; selectedAudioVolume: number; selectedId: string | null; sourceDiagnostics?:ScreenDiagnostics }>(), { screenWatcherIds: () => [] })
const emit = defineEmits<{ changeQuality: []; clear: []; retry: [automatic?: boolean]; select: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setAudioVolume: [percent: number]; stopScreen: []; toggleAudio: []; 'update:expanded': [expanded: boolean] }>()
const video = ref<HTMLVideoElement | null>(null)
const audio = ref<HTMLAudioElement | null>(null)
const stage = ref<HTMLDivElement | null>(null)
const viewerElement = ref<HTMLElement | null>(null)
const moreActions = ref<HTMLDetailsElement | null>(null)
const auxiliaryPanel = ref<'streams' | 'participants' | null>(null)
const auxiliaryTrigger = ref<HTMLElement | null>(null)
const diagnosisToolsOpen = ref(false)
const diagnosisTrigger = ref<HTMLButtonElement | null>(null)
function closeDiagnosisTools(): void {
  diagnosisToolsOpen.value = false
  const trigger = diagnosisTrigger.value?.getClientRects().length ? diagnosisTrigger.value : moreActions.value?.querySelector('summary')
  trigger?.focus(); revealStageControls()
}
function openDiagnosisTools(): void {
  if (moreActions.value) moreActions.value.open = false
  diagnosisToolsOpen.value = true
  revealStageControls()
}
function togglePanel(panel: 'streams' | 'participants', event: MouseEvent): void {
  auxiliaryTrigger.value = event.currentTarget as HTMLElement
  auxiliaryPanel.value = auxiliaryPanel.value === panel ? null : panel
}
function dismissPanels(event: PointerEvent): void {
  if (!(event.target instanceof Element)) return
  if (!event.target.closest('.screen-viewer-panels')) auxiliaryPanel.value = null
  if (!event.target.closest('.screen-diagnosis, .screen-diagnosis-toggle')) diagnosisToolsOpen.value = false
}
const fullscreenActive = ref(false)
const fullscreenFeedback = ref('')
const playbackFeedback = ref('')
const videoPaused = ref(false)
const stageControlsVisible = ref(false)
const videoPlaybackBlocked=ref(false),audioPlaybackBlocked=ref(false)
const playbackBlocked = computed(() => videoPlaybackBlocked.value || audioPlaybackBlocked.value)
let playbackRequestGeneration=0,requestedSelectionId:string|null=null
const { firstFrameMs, presentationSource, actualVideoQuality, markVideoReady,playbackFps,presentedFrames,refreshVideoQuality, resetVideoFrame, videoReady } = useScreenPlaybackQuality(video, () => props.selectedId, () => props.ended)
let fullscreenControls: ReturnType<typeof createScreenFullscreenControls> | null = null
let stopReporting: (() => void) | null = null
let stageControlsHideTimer: number | null = null
const selectedStream = computed(() => props.cards.find((stream) => stream.id === props.selectedId) ?? null)
const {metrics:receiverMetrics,sampledAt:receiverSampledAt,refresh:refreshReceiverMetrics}=useScreenReceiverDiagnostics(selectedStream,()=>props.ended)
const adjustable = computed(() => Boolean(selectedStream.value?.hasAudio && selectedStream.value.accountId && !selectedStream.value.isLocal))
const audioMessage = computed(() => selectedStream.value ? screenAudioMessage({ isLocal: Boolean(selectedStream.value.isLocal), hasAudio: selectedStream.value.hasAudio, adjustable: adjustable.value, deafened: props.deafened }) : '')
function reportPlaybackError(cause:unknown,audioOutput=false):void {if(cause instanceof DOMException&&cause.name==='NotAllowedError'){if(audioOutput){audioPlaybackBlocked.value=true;playbackFeedback.value='Браузер заблокировал звук. Нажмите «Повторить» ещё раз после разрешения звука.';return}videoPlaybackBlocked.value=true;playbackFeedback.value='Браузер заблокировал воспроизведение. Нажмите «Повторить» после разрешения.'}}
function playFromGesture():void {const generation=++playbackRequestGeneration;if(video.value && !videoPaused.value)void video.value.play().then(()=>{if(generation===playbackRequestGeneration){videoPlaybackBlocked.value=false;if(!audioPlaybackBlocked.value)playbackFeedback.value=''}}).catch(cause=>{if(generation===playbackRequestGeneration)reportPlaybackError(cause)});void audio.value?.play().then(()=>{if(generation===playbackRequestGeneration){audioPlaybackBlocked.value=false;if(!videoPlaybackBlocked.value)playbackFeedback.value=''}}).catch(cause=>{if(generation===playbackRequestGeneration)reportPlaybackError(cause,true)})}
async function toggleVideoPause(): Promise<void> {
  if (!video.value || props.ended) return
  if (!videoPaused.value) { videoPaused.value = true; video.value.pause(); return }
  const generation = ++playbackRequestGeneration
  try {
    await video.value.play()
    if (generation === playbackRequestGeneration) { videoPaused.value = false; videoPlaybackBlocked.value = false; playbackFeedback.value = '' }
  } catch (cause) { if (generation === playbackRequestGeneration) reportPlaybackError(cause) }
}
function select(id: string): void { if (auxiliaryPanel.value) void nextTick(() => auxiliaryTrigger.value?.focus()); auxiliaryPanel.value = null; if (id === props.selectedId) return; requestedSelectionId=id;videoPlaybackBlocked.value=false;audioPlaybackBlocked.value=false;markScreenSelected(video.value);emit('select',id,video.value,audio.value);playFromGesture() }
function retry(automatic=false): void {
  playbackFeedback.value = ''
  if(!automatic&&playbackBlocked.value){markScreenSelected(video.value);if(videoPlaybackBlocked.value)resetVideoFrame();playFromGesture();return}
  markScreenSelected(video.value)
  resetVideoFrame()
  emit('retry',automatic)
  if(!automatic)playFromGesture()
}
function changeQuality(): void { if (moreActions.value) moreActions.value.open = false; emit('changeQuality') }
function revealStageControls(): void {
  stageControlsVisible.value = true
  if (stageControlsHideTimer !== null) window.clearTimeout(stageControlsHideTimer)
  stageControlsHideTimer = window.setTimeout(() => {
    if (!moreActions.value?.open && !diagnosisToolsOpen.value && !viewerElement.value?.querySelector('.stream-diagnostics[open]')) stageControlsVisible.value = false
    stageControlsHideTimer = null
  }, 1800)
}
async function stopWatching(): Promise<void> {
  if (moreActions.value) moreActions.value.open = false
  if (fullscreenActive.value) {
    try {
      const available = await fullscreenControls?.toggle()
      if (!available) { fullscreenFeedback.value = 'Полноэкранный режим недоступен в этом браузере.'; return }
    } catch {
      fullscreenFeedback.value = 'Не удалось выйти из полноэкранного режима.'
      return
    }
  }
  emit('clear')
}
function selectStream(id: string): void { select(id) }
defineExpose({ selectStream })
function stageVisible():boolean {const box=stage.value?.getBoundingClientRect();return Boolean(document.visibilityState==='visible'&&box&&box.width>0&&box.height>0&&box.bottom>0&&box.right>0&&box.top<innerHeight&&box.left<innerWidth)}
watch(()=>props.selectedId,id=>{videoPaused.value=false;if(requestedSelectionId===id){requestedSelectionId=null;return}requestedSelectionId=null;playbackRequestGeneration+=1;videoPlaybackBlocked.value=false;audioPlaybackBlocked.value=false})
watch(() => props.expanded, async () => {
  await nextTick()
  const selector = props.mini ? '.screen-mini-actions button[aria-label="Развернуть на всю область"]' : '.stream-more-actions > summary'
  viewerElement.value?.querySelector<HTMLElement>(selector)?.focus({ preventScroll: true })
})
function handleKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && (auxiliaryPanel.value || diagnosisToolsOpen.value)) {
    if (diagnosisToolsOpen.value) closeDiagnosisTools()
    else { auxiliaryPanel.value = null; auxiliaryTrigger.value?.focus({ preventScroll: true }) } event.preventDefault(); event.stopImmediatePropagation(); return
  }
  if (event.key === 'Escape' && props.expanded) emit('update:expanded', false)
}
onMounted(() => {
  fullscreenControls = createScreenFullscreenControls(() => stage.value, document, (active) => { fullscreenActive.value = active })
  const platform = webPlatform(navigator.userAgent)
  stopReporting = startScreenClientReporting(() => buildScreenClientReport({
    platform, selected: !videoPaused.value && Boolean(selectedStream.value && !selectedStream.value.isLocal && !props.ended),
    hasTrack: Boolean(selectedStream.value?.readReceiverStats), videoReady: videoReady.value,
    firstFrameMs: firstFrameMs.value, presentationSource: presentationSource.value, playbackFps: playbackFps.value, receiverMetrics: receiverMetrics.value,
    sampledAt: receiverSampledAt.value ?? undefined,
    frameWidth: video.value?.videoWidth, frameHeight: video.value?.videoHeight,
  }), () => document.visibilityState === 'visible')
  window.addEventListener('keydown', handleKeydown)
  document.addEventListener('pointerdown', dismissPanels, true)
})
onBeforeUnmount(() => {
  stopReporting?.()
  fullscreenControls?.dispose()
  if (stageControlsHideTimer !== null) window.clearTimeout(stageControlsHideTimer)
  window.removeEventListener('keydown', handleKeydown)
  document.removeEventListener('pointerdown', dismissPanels, true)
  if (props.expanded) emit('update:expanded', false)
  emit('clear')
})
async function toggleFullscreen(): Promise<void> {
  fullscreenFeedback.value = ''
  try {
    const available = await fullscreenControls?.toggle()
    if (!available) fullscreenFeedback.value = 'Полноэкранный режим недоступен в этом браузере.'
    else revealStageControls()
  } catch {
    fullscreenFeedback.value = 'Не удалось изменить режим полноэкранного просмотра.'
  }
}
</script>
<template>
  <section ref="viewerElement" class="screen-viewer stream-wrap" :class="{ 'screen-viewer--compact': !mini }" aria-label="Демонстрация экрана">
    <ScreenMiniToolbar v-if="mini && selectedId" :name="selectedStream?.participantName ?? 'Демонстрация'" :paused="videoPaused" :ended="ended" :ready="videoReady" :has-audio="Boolean(selectedStream?.hasAudio && !selectedStream.isLocal)" :muted="audioMuted || selectedAudioVolume === 0" :deafened="deafened"
    @pause="toggleVideoPause" @audio="emit('toggleAudio');audioPlaybackBlocked && playFromGesture()" @expand="emit('update:expanded', true)" @close="emit('clear')" />
    <div ref="stage" class="screen-stage" :class="{ 'screen-stage--waiting': !selectedStream }" @pointermove="revealStageControls" @pointerdown="revealStageControls">
      <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
      <p v-if="ended" class="state" role="status">{{ mini ? 'Трансляция завершена' : 'Демонстрация завершена. Выберите другую вручную или вернитесь к участникам.' }}</p>
      <p v-else-if="selectedStream && !videoReady" class="state screen-loading-state" role="status">{{ mini ? 'Подключение…' : 'Получаем первый кадр демонстрации…' }}</p>
      <p v-else-if="!selectedId && cards.length === 0" class="state">Участники пока не показывают экран.</p>
      <p v-else-if="!selectedId" class="state">Выберите демонстрацию. Загружается только один выбранный поток.</p>
      <span v-if="videoPaused" class="screen-pause-label" role="status">Видео на паузе</span>
      <video ref="video" v-show="selectedId" class="screen-player" autoplay playsinline :muted="selectedStream?.isLocal ?? false" aria-label="Выбранная демонстрация" @loadedmetadata="refreshVideoQuality" @resize="refreshVideoQuality" @loadeddata="markVideoReady" @emptied="resetVideoFrame"></video>
      <div class="screen-stage-top">
        <span v-if="selectedStream" class="screen-stage-label"><span class="screen-stage-avatar" :style="{ backgroundColor: avatarBackground(selectedStream.accountId ?? selectedStream.participantId), color: avatarForeground(selectedStream.accountId ?? selectedStream.participantId) }" aria-hidden="true">{{ selectedStream.participantName.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span>{{ selectedStream.isLocal ? 'Ваш экран' : `Экран ${selectedStream.participantName || 'участника'}` }}<b>ЭФИР</b><small v-if="selectedStream.isLocal && !selectedStream.hasAudio" title="Предпросмотр без звука">Без звука</small></span>
        <div v-if="!mini" class="screen-viewer-panels">
          <div class="screen-viewer-panel-toggles">
            <button v-if="cards.length > 1 || !selectedStream && cards.length" type="button" :aria-expanded="auxiliaryPanel === 'streams'" @click="togglePanel('streams', $event)">Трансляции · {{ cards.length }}</button>
            <button type="button" :aria-expanded="auxiliaryPanel === 'participants'" @click="togglePanel('participants', $event)">Участники · {{ participants.length + 1 }}<span> · Зрители · {{ screenWatcherIds.length }}</span></button>
          </div>
          <div v-if="auxiliaryPanel" class="screen-viewer-panel-content" :class="{ 'screen-viewer-panel-content--participants': auxiliaryPanel === 'participants' }">
            <button class="screen-viewer-panel-close" type="button" aria-label="Закрыть панель просмотра" @click="auxiliaryPanel = null; auxiliaryTrigger?.focus()">×</button>
            <ScreenViewerRail v-if="auxiliaryPanel === 'streams'" :cards="cards" :selected-id="selectedId" :show-return-to-voice="false" @select="select" />
            <ScreenViewerParticipantStrip v-if="auxiliaryPanel === 'participants'" :participants="participants" :screens="cards" :selected-id="selectedId" :screen-watcher-ids="screenWatcherIds" :self-account-id="selfAccountId" :self-deafened="deafened" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-name="selfName" :self-speaking="selfSpeaking" :own-screen-sharing="Boolean(ownScreenSharing)" />
          </div>
        </div>
      </div>
      <div v-if="!mini && selectedStream" class="screen-stage-actions" :class="{ 'screen-stage-actions--visible': stageControlsVisible }" role="group" aria-label="Управление просмотром" @focusin="revealStageControls">
        <button class="screen-stage-action screen-stage-action--size" type="button" :aria-label="fullscreenActive ? 'Свернуть просмотр' : 'Развернуть на весь экран'" :title="fullscreenActive ? 'Свернуть просмотр' : 'Развернуть на весь экран'" @click="toggleFullscreen"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="fullscreenActive" d="M8 3v5H3M16 3v5h5M3 16h5v5M21 16h-5v5"/><path v-else d="M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5"/></svg><span>{{ fullscreenActive ? 'Свернуть' : 'Развернуть' }}</span></button>
        <button v-if="!selectedStream.isLocal" class="screen-stage-action screen-stage-action--stop" type="button" aria-label="Прекратить просмотр" title="Прекратить просмотр этой трансляции" @click="stopWatching"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg><span>Прекратить просмотр</span></button>
        <div v-if="selectedStream" class="stream-quality-row">
          <ScreenViewerAudioControl v-if="selectedStream.hasAudio && !selectedStream.isLocal" :adjustable="adjustable" :deafened="deafened" :muted="audioMuted" :volume="selectedAudioVolume" @toggle="emit('toggleAudio');audioPlaybackBlocked&&playFromGesture()" @set-volume="emit('setAudioVolume', $event)" />
          <p v-if="audioMessage" class="stream-audio-status gc-sr-only" role="status">{{ audioMessage }}</p>
          <div class="stream-toolbar-actions">
            <button v-if="ownScreenSharing" type="button" class="stream-tool-button stream-stop-screen-button" aria-label="Остановить свою трансляцию" title="Остановить свою трансляцию" @click="emit('stopScreen')"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="6" width="12" height="12" rx="2" /></svg><span>Остановить</span></button>
            <button type="button" class="stream-tool-button" :disabled="ended || !videoReady" :aria-label="videoPaused ? 'Продолжить видео' : 'Приостановить видео'" :aria-pressed="videoPaused" @click="toggleVideoPause"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="videoPaused" d="m8 4 12 8-12 8Z"/><path v-else d="M8 4v16M16 4v16"/></svg></button>
            <button type="button" ref="diagnosisTrigger" class="stream-tool-button screen-diagnosis-toggle" aria-label="Диагностика просмотра" :aria-expanded="diagnosisToolsOpen" @click="diagnosisToolsOpen = !diagnosisToolsOpen"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12h4l3-7 4 14 3-7h4" /></svg></button>
            <ScreenReceiverDiagnosticsPanel @toggle="revealStageControls" :actual-video-quality="actualVideoQuality" :has-audio="selectedStream.hasAudio" :is-local="Boolean(selectedStream.isLocal)" :metrics="receiverMetrics" :sampled-at="receiverSampledAt" :target-profile="selectedStream.targetProfile" :descriptor="selectedStream.descriptor" :metadata-receipt-key="selectedStream.id" :sender-diagnostics="selectedStream.isLocal ? sourceDiagnostics : undefined" :profile-source="selectedStream.profileSource" :participant-name="selectedStream.participantName" :presented-fps="playbackFps" />
            <details ref="moreActions" class="stream-more-actions" @toggle="revealStageControls"><summary class="stream-tool-button" aria-label="Дополнительные действия"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg></summary><div class="stream-voice-return"><p class="gc-sr-only">{{ participantAudioMessage(deafened) }}</p><button class="stream-diagnosis-menu-action" type="button" @click="openDiagnosisTools">Диагностика просмотра</button><button v-if="ownScreenSharing" type="button" @click="changeQuality">Качество трансляции</button><button type="button" @click="emit('update:expanded', !expanded)">{{ expanded ? 'Вернуть в окно канала' : 'Развернуть на всю область' }}</button><button type="button" @click="stopWatching">К участникам</button></div></details>
          </div>
        </div>
      </div>
      <DiagnosisPanel v-if="selectedStream" v-show="!mini && !videoPaused" :compact="!mini" :tools-open="diagnosisToolsOpen" @close-tools="closeDiagnosisTools" :selected-id="selectedId" :ended="ended" :has-audio="selectedStream.hasAudio" :local="Boolean(selectedStream.isLocal)" :publisher-paused="videoPaused || Boolean(selectedStream.videoMuted)" :autoplay-blocked="playbackBlocked" :subscription-failed="error === 'Не удалось подписаться на демонстрацию.'" :stage-visible="stageVisible" :video-ready="videoReady" :presented-fps="playbackFps" :presented-frames="presentedFrames" :sampled-at="receiverSampledAt" :metrics="receiverMetrics" :source="sourceDiagnostics" @refresh="refreshReceiverMetrics" @retry="retry(false)" @auto-retry="retry(true)" @choose="emit('clear')" />
      <p v-if="fullscreenFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ fullscreenFeedback }}</p>
      <p v-if="playbackFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ playbackFeedback }}</p>
    </div>
    <audio ref="audio" autoplay></audio>
  </section>
</template>
