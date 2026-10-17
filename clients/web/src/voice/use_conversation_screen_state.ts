import { computed, nextTick, ref, shallowRef, watch } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import { miniPlayerVisible, screenViewerMounted } from './mini_player_policy'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import type { ScreenViewerCard } from './screen_viewer_controller'

interface ConversationScreenProps {
  visible: boolean
  channel: TopologyChannel | null
  activeVoiceChannel: TopologyChannel | null
  directMessage: unknown
  selectedScreenStreamId: string | null
  screenViewerCards: ScreenViewerCard[]
  screenViewerEnded: boolean
}

export function useConversationScreenState(props: ConversationScreenProps) {
  const screenCaptureAvailable = screenCaptureSupported()
  const captureUnavailableMessage = screenCaptureUnavailableMessage()
  const screenExpanded = ref(false)
  const screenPinned = ref(false)
  const voiceVisible = computed(() => props.visible && !props.directMessage && props.channel?.kind === 'VOICE')
  const voiceChannel = computed(() => props.channel?.kind === 'VOICE' ? props.channel : props.activeVoiceChannel)
  const miniVisible = computed(() => !screenExpanded.value && miniPlayerVisible(screenPinned.value, voiceVisible.value, props.selectedScreenStreamId, props.activeVoiceChannel?.id ?? null))
  const keepVoiceRoom = computed(() => screenViewerMounted(screenPinned.value, voiceVisible.value, props.selectedScreenStreamId, props.activeVoiceChannel?.id ?? null))
  const selectedScreenName = computed(() => props.screenViewerCards.find((screen) => screen.id === props.selectedScreenStreamId)?.participantName ?? null)
  const screenViewerRef = shallowRef<{ selectStream: (id: string) => void } | null>(null)
  let dismissedLocalPreviewId: string | null = null
  const localScreenId = computed(() => props.screenViewerCards.find((screen) => screen.isLocal)?.id ?? null)
  watch(voiceVisible, (visible) => { if (!visible) screenExpanded.value = false })
  watch(() => props.activeVoiceChannel?.id, () => { screenPinned.value = false; screenExpanded.value = false })
  watch(() => props.selectedScreenStreamId, (id) => { if (!id) { screenPinned.value = false; screenExpanded.value = false } })
  watch([localScreenId, () => props.selectedScreenStreamId, () => props.screenViewerEnded], async ([localId, selectedId, ended]) => {
    if (!localId || selectedId !== null || ended || localId === dismissedLocalPreviewId) return
    await nextTick()
    if (props.selectedScreenStreamId === null && !props.screenViewerEnded && localScreenId.value === localId) {
      screenViewerRef.value?.selectStream(localId)
    }
  }, { flush: 'post', immediate: true })
  function watchScreen(id: string): void {
    if (props.screenViewerCards.some((screen) => screen.id === id && screen.isLocal)) dismissedLocalPreviewId = null
    screenViewerRef.value?.selectStream(id)
  }
  function dismissLocalPreview(): void { dismissedLocalPreviewId = localScreenId.value }
  return { screenCaptureAvailable, captureUnavailableMessage, screenExpanded, screenPinned,
    voiceChannel, miniVisible, keepVoiceRoom, selectedScreenName, screenViewerRef, watchScreen, dismissLocalPreview }
}
