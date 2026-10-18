import { onBeforeUnmount, ref, watch, type Ref } from 'vue'

import { compareScreenReceiverStats, type ScreenReceiverMetrics, type ScreenReceiverSnapshot } from './screen_receiver_diagnostics'
import { ScreenPacketLossWindow } from './screen_packet_loss'
import type { ScreenViewerCard } from './screen_viewer_types'

export function useScreenReceiverDiagnostics(selected: Ref<ScreenViewerCard | null>, ended: () => boolean) {
  const metrics = ref<ScreenReceiverMetrics | null>(null)
  const sampledAt = ref<number | null>(null)
  let previous: ScreenReceiverSnapshot | null = null
  const lossWindow = new ScreenPacketLossWindow()
  let generation = 0
  let timer: ReturnType<typeof setInterval> | null = null
  let sampling = false

  async function sample(card: ScreenViewerCard, version: number): Promise<void> {
    if (sampling || !card.readReceiverStats) return
    sampling = true
    try {
      const current = await card.readReceiverStats()
      if (version !== generation) return
      // A transient missing row must not erase the last good sample. The diagnosis
      // panel marks it stale only after its normal freshness window expires.
      if (!current) return
      if (previous?.streamId !== current.streamId || previous?.ssrc !== current.ssrc) lossWindow.clear()
      if (previous?.timestamp === current.timestamp) return
      const packetLossPercent = lossWindow.add(current)
      metrics.value = { ...compareScreenReceiverStats(previous, current), packetLossPercent, packetLossWindowMs: lossWindow.durationMs }
      sampledAt.value = current.timestamp
      previous = current
    } catch {
      // Keep the last successful observation through a brief getStats failure.
    } finally {
      if (version === generation) sampling = false
    }
  }

  function restart(): void {
    generation += 1
    if (timer) clearInterval(timer)
    timer = null
    sampling = false
    previous = null
    lossWindow.clear()
    metrics.value = null
    sampledAt.value = null
    const card = selected.value
    if (!card?.readReceiverStats || ended()) return
    const version = generation
    void sample(card, version)
    timer = setInterval(() => { void sample(card, version) }, 1000)
  }

  watch([() => selected.value?.id, () => selected.value?.readReceiverStats, ended], restart, { immediate: true })
  onBeforeUnmount(() => { generation += 1; if (timer) clearInterval(timer) })
  return { metrics,sampledAt,refresh:()=>{const card=selected.value;if(card&&!ended()) void sample(card,generation)} }
}
