import { ref, type Ref } from 'vue'
import { createViewObservation } from '../telemetry/observe_render/screen'

import type { ScreenViewerCard, ScreenViewerController } from './screen_viewer_controller'

export interface ScreenViewerSession {
  screenViewer(): ScreenViewerController | null
}

export function createScreenViewerControls(
  session: ScreenViewerSession,
  cards: Ref<ScreenViewerCard[]>,
  selectedId: Ref<string | null>,
  error: Ref<string | null>,
  ended: Ref<boolean>,
  watcherIds?: Ref<string[]>,
  ownerWatcherIds?: Ref<string[]>,
) {
  let controller: ScreenViewerController | null = null
  const observation = createViewObservation()
  let stopObserving: (() => void) | null = null
  let selectedVideo: HTMLVideoElement | null = null
  let observedSelection: { id: string; operation: number; video: HTMLVideoElement | null } | null = null
  const audioMuted = ref(false)
  const subscriptionError = 'Не удалось подписаться на демонстрацию.'

  function sync(): void {
    cards.value = controller?.cards() ?? []
    if (watcherIds) watcherIds.value = controller?.watchers().map(watcher => watcher.id) ?? []
    if (ownerWatcherIds) ownerWatcherIds.value = controller?.ownerWatchers().map(watcher => watcher.id) ?? []
    selectedId.value = controller?.selectedId ?? null
    ended.value = controller?.ended ?? false
    audioMuted.value = controller?.audioMuted ?? false
    if (controller?.subscriptionFailed) error.value = subscriptionError
    else if (error.value === subscriptionError) error.value = null
    if (!controller?.selectedId) {
      if (observedSelection) observation.stop()
      observedSelection = null
    } else if (selectedVideo) observeSelection(controller.selectedId, selectedVideo)
  }

  function start(): void {
    stopObserving?.()
    controller = session.screenViewer()
    selectedVideo = null
    observedSelection = null
    stopObserving = controller?.onChange(sync) ?? null
    error.value = null
    sync()
  }

  function select(id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    if (!controller) return
    const previousVideo = selectedVideo
    try {
      const previousId = controller.selectedId
      const previousOperation = controller.operationGeneration
      selectedVideo = video
      controller.select(id, video, audio)
      if (previousId === id && previousOperation === controller.operationGeneration) return
      observeSelection(id, video)
      error.value = null
    } catch (cause) {
      selectedVideo = previousVideo
      observation.fail()
      error.value = cause instanceof Error ? cause.message : 'Не удалось выбрать демонстрацию.'
    }
  }

  function stop(): void {
    observation.stop()
    observedSelection = null
    stopObserving?.()
    stopObserving = null
    controller?.stop()
    controller = null
    selectedVideo = null
    error.value = null
    sync()
  }

  function clear(): void {
    observation.stop()
    observedSelection = null
    selectedVideo = null
    controller?.clear()
  }

  function retry(automatic = false): boolean {
    if (!controller?.selectedId) return false
    const selectedId = controller.selectedId
    if (!controller.retry(automatic)) {
      observation.fail()
      error.value = automatic ? 'Автоматическое восстановление исчерпано. Повторите подключение вручную.' : 'Не удалось восстановить демонстрацию. Выберите её снова.'
      return false
    }
    observeSelection(selectedId, selectedVideo)
    error.value = null
    return true
  }

  function observeSelection(id: string, video: HTMLVideoElement | null): void {
    const selectedController = controller
    if (!selectedController) return
    const generation = selectedController.operationGeneration
    if (observedSelection?.id === id && observedSelection.operation === generation && observedSelection.video === video) return
    observedSelection = { id, operation: generation, video }
    observation.select(video, () => selectedController === controller && selectedController.operationGeneration === generation
      && selectedController.selectedId === id && selectedController.hasAttachedVideo(video), id)
  }

  function toggleAudio(volume: number, setVolume: (percent: number) => void): void {
    if (!controller?.selectedId) return
    if (volume === 0) {
      setVolume(100)
      if (controller.audioMuted) controller.setAudioMuted(false)
      return
    }
    controller.setAudioMuted(!controller.audioMuted)
  }

  return { audioMuted, clear, refreshWatchers: () => controller?.refreshWatchers() ?? Promise.resolve(), retry, select, start, stop, toggleAudio }
}
