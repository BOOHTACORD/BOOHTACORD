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
const props = defineProps<{ audioMuted: boolean; cards: ScreenViewerCard[]; deafened: boolean; ended: boolean; error: string | null; expanded: boolean; mini?: boolean; ownScreenSharing?: boolean; pinned?: boolean; participants: VoiceVolumeParticipant[]; selfAccountId?: string; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfName: string | null; selfSpeaking: boolean; selectedAudioVolume: number; selectedId: string | null; sourceDiagnostics?:ScreenDiagnostics }>()
const emit = defineEmits<{ changeQuality: []; clear: []; pin: []; retry: [automatic?: boolean]; select: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setAudioVolume: [percent: number]; toggleAudio: []; 'update:expanded': [expanded: boolean] }>()
const video = ref<HTMLVideoElement | null>(null)
const audio = ref<HTMLAudioElement | null>(null)
const stage = ref<HTMLDivElement | null>(null)
const viewerElement = ref<HTMLElement | null>(null)
const moreActions = ref<HTMLDetailsElement | null>(null)
const fullscreenActive = ref(false)
const fullscreenFeedback = ref('')
const playbackFeedback = ref('')
const videoPaused = ref(false)
const videoPlaybackBlocked=ref(false),audioPlaybackBlocked=ref(false)
const playbackBlocked = computed(() => videoPlaybackBlocked.value || audioPlaybackBlocked.value)
let playbackRequestGeneration=0,requestedSelectionId:string|null=null
const { firstFrameMs, presentationSource, actualVideoQuality, markVideoReady,playbackFps,presentedFrames,refreshVideoQuality, resetVideoFrame, videoReady } = useScreenPlaybackQuality(video, () => props.selectedId, () => props.ended)
let fullscreenControls: ReturnType<typeof createScreenFullscreenControls> | null = null
let stopReporting: (() => void) | null = null
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
function select(id: string): void { if (id === props.selectedId) return; requestedSelectionId=id;videoPlaybackBlocked.value=false;audioPlaybackBlocked.value=false;markScreenSelected(video.value);emit('select',id,video.value,audio.value);playFromGesture() }
function retry(automatic=false): void {
  playbackFeedback.value = ''
  if(!automatic&&playbackBlocked.value){markScreenSelected(video.value);if(videoPlaybackBlocked.value)resetVideoFrame();playFromGesture();return}
  markScreenSelected(video.value)
  resetVideoFrame()
  emit('retry',automatic)
  if(!automatic)playFromGesture()
}
function changeQuality(): void { if (moreActions.value) moreActions.value.open = false; emit('changeQuality') }
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
})
onBeforeUnmount(() => {
  stopReporting?.()
  fullscreenControls?.dispose()
  window.removeEventListener('keydown', handleKeydown)
  if (props.expanded) emit('update:expanded', false)
  emit('clear')
})
async function toggleFullscreen(): Promise<void> {
  fullscreenFeedback.value = ''
  try {
    const available = await fullscreenControls?.toggle()
    if (!available) fullscreenFeedback.value = 'Полноэкранный режим недоступен в этом браузере.'
  } catch {
    fullscreenFeedback.value = 'Не удалось развернуть демонстрацию на весь экран.'
  }
}
</script>
<template>
  <section ref="viewerElement" class="screen-viewer stream-wrap" aria-label="Демонстрация экрана">
      <ScreenMiniToolbar v-if="mini && selectedId" :name="selectedStream?.participantName ?? 'Демонстрация'" :paused="videoPaused" :ended="ended" :ready="videoReady" :has-audio="Boolean(selectedStream?.hasAudio && !selectedStream.isLocal)" :muted="audioMuted || selectedAudioVolume === 0" :deafened="deafened"
        @pause="toggleVideoPause" @audio="emit('toggleAudio');audioPlaybackBlocked && playFromGesture()" @unpin="emit('pin')" @expand="emit('update:expanded', true)" @close="emit('clear')" />
      <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
      <div ref="stage" class="screen-stage" :class="{ 'screen-stage--waiting': !selectedStream }">
      <p v-if="ended" class="state" role="status">{{ mini ? 'Трансляция завершена' : 'Демонстрация завершена. Выберите другую вручную или вернитесь к участникам.' }}</p>
      <p v-else-if="selectedStream && !videoReady" class="state screen-loading-state" role="status">{{ mini ? 'Подключение…' : 'Получаем первый кадр демонстрации…' }}</p>
      <p v-else-if="!selectedId && cards.length === 0" class="state">Участники пока не показывают экран.</p>
      <p v-else-if="!selectedId" class="state">Выберите демонстрацию. Загружается только один выбранный поток.</p>
      <span v-if="videoPaused" class="screen-pause-label" role="status">Видео на паузе</span>
      <video ref="video" v-show="selectedId" class="screen-player" autoplay playsinline :muted="selectedStream?.isLocal ?? false" aria-label="Выбранная демонстрация" @loadedmetadata="refreshVideoQuality" @resize="refreshVideoQuality" @loadeddata="markVideoReady" @emptied="resetVideoFrame"></video>
      <template v-if="selectedStream">
        <div class="screen-stage-top">
          <span class="screen-stage-label"><span class="screen-stage-avatar" :style="{ backgroundColor: avatarBackground(selectedStream.accountId ?? selectedStream.participantId), color: avatarForeground(selectedStream.accountId ?? selectedStream.participantId) }" aria-hidden="true">{{ selectedStream.participantName.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span>{{ selectedStream.isLocal ? 'Ваш экран' : `Экран ${selectedStream.participantName || 'участника'}` }}<b>ЭФИР</b></span>
        </div>
      </template>
      <p v-if="fullscreenFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ fullscreenFeedback }}</p>
      <p v-if="playbackFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ playbackFeedback }}</p>
    </div>
    <audio ref="audio" autoplay></audio>
    <DiagnosisPanel v-if="selectedStream" v-show="!mini && !videoPaused" :selected-id="selectedId" :ended="ended" :has-audio="selectedStream.hasAudio" :local="Boolean(selectedStream.isLocal)" :publisher-paused="videoPaused || Boolean(selectedStream.videoMuted)" :autoplay-blocked="playbackBlocked" :subscription-failed="error === 'Не удалось подписаться на демонстрацию.'" :stage-visible="stageVisible" :video-ready="videoReady" :presented-fps="playbackFps" :presented-frames="presentedFrames" :sampled-at="receiverSampledAt" :metrics="receiverMetrics" :source="sourceDiagnostics" @refresh="refreshReceiverMetrics" @retry="retry(false)" @auto-retry="retry(true)" @choose="emit('clear')" />
    <div v-if="selectedStream" class="stream-quality-row">
      <ScreenViewerAudioControl v-if="selectedStream.hasAudio && !selectedStream.isLocal" :adjustable="adjustable" :deafened="deafened" :muted="audioMuted" :volume="selectedAudioVolume" @toggle="emit('toggleAudio');audioPlaybackBlocked&&playFromGesture()" @set-volume="emit('setAudioVolume', $event)" />
      <p v-if="audioMessage" class="stream-audio-status gc-sr-only" role="status">{{ audioMessage }}</p>
      <div class="stream-toolbar-actions">
        <button type="button" class="stream-tool-button" :disabled="ended || !videoReady" :aria-label="videoPaused ? 'Продолжить видео' : 'Приостановить видео'" :aria-pressed="videoPaused" @click="toggleVideoPause"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="videoPaused" d="m8 4 12 8-12 8Z"/><path v-else d="M8 4v16M16 4v16"/></svg></button>
        <button type="button" class="stream-tool-button" :aria-label="pinned ? 'Открепить просмотр' : 'Закрепить просмотр'" :aria-pressed="Boolean(pinned)" @click="emit('pin')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m16 3 5 5-4 2-3 5-2 1-4-4 1-2 5-3 2-4ZM8 16l-5 5"/></svg></button>
        <ScreenReceiverDiagnosticsPanel :actual-video-quality="actualVideoQuality" :has-audio="selectedStream.hasAudio" :is-local="Boolean(selectedStream.isLocal)" :metrics="receiverMetrics" :sampled-at="receiverSampledAt" :target-profile="selectedStream.targetProfile" :descriptor="selectedStream.descriptor" :metadata-receipt-key="selectedStream.id" :sender-diagnostics="selectedStream.isLocal ? sourceDiagnostics : undefined" :profile-source="selectedStream.profileSource" :participant-name="selectedStream.participantName" :presented-fps="playbackFps" />
        <button class="screen-fullscreen-button stream-tool-button" type="button" :aria-label="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" :aria-pressed="fullscreenActive" :title="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" @click="toggleFullscreen"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="fullscreenActive" d="M9 3v6H3M15 3v6h6M3 15h6v6M21 15h-6v6" /><path v-else d="M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5" /></svg></button>
        <details ref="moreActions" class="stream-more-actions"><summary class="stream-tool-button" aria-label="Дополнительные действия"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg></summary><div class="stream-voice-return"><p class="gc-sr-only">{{ participantAudioMessage(deafened) }}</p><button v-if="ownScreenSharing" type="button" @click="changeQuality">Качество трансляции</button><button type="button" @click="emit('update:expanded', !expanded)">{{ expanded ? 'Вернуть в окно канала' : 'Развернуть на всю область' }}</button><button type="button" @click="emit('clear')">К участникам</button></div></details>
      </div>
    </div>
    <ScreenViewerRail v-if="cards.length" :cards="cards" :selected-id="selectedId" :show-return-to-voice="false" @select="select" />
    <ScreenViewerParticipantStrip v-if="!mini" :participants="participants" :screens="cards" :self-account-id="selfAccountId" :self-deafened="deafened" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-name="selfName" :self-speaking="selfSpeaking" :own-screen-sharing="Boolean(ownScreenSharing)" />
  </section>
</template>
