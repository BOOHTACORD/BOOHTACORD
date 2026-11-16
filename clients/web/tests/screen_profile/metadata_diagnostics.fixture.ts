import { createApp, h, reactive } from 'vue'
import ScreenReceiverDiagnosticsPanel from '../../src/voice/ScreenReceiverDiagnosticsPanel.vue'
import type { ScreenReceiverMetrics } from '../../src/voice/screen_receiver_diagnostics'
import '../../src/style.css'
import fixture from '../../../../contracts/screen-share-profile-v1.fixtures.json'
import type { ScreenShareDescriptorV1 } from '../../src/voice/screen_profile_metadata/types'

const state = reactive({ descriptor: fixture.validDescriptor as ScreenShareDescriptorV1 | undefined, metrics: null as ScreenReceiverMetrics | null })
Object.assign(window, {
  qaDescriptorState: (kind: 'sharing' | 'updating' | 'idle' | 'missing') => {
    state.descriptor = kind === 'missing' ? undefined : { ...fixture.validDescriptor as ScreenShareDescriptorV1, publisher_state: kind }
  },
  qaReceiverMetrics: () => {
    state.metrics = {
      bitrateKbps: 1500, decodedFps: 29.5, droppedFrames: 1, jitterMs: 5,
      packetsLost: 3, packetLossPercent: 0.5, packetLossWindowMs: 10000, rttMs: 40,
      decodeMsPerFrame: 4, jitterBufferMsPerFrame: 6, nackPerSecond: 1, pliPerSecond: 0,
      firPerSecond: 0, freezeCount: 0, freezeDurationMs: 0, decodedFrames: 100,
    }
  },
})
createApp({ render: () => h(ScreenReceiverDiagnosticsPanel, {
  actualVideoQuality: 'Нет данных', hasAudio: false, isLocal: false,
  metrics: state.metrics, sampledAt: state.metrics ? Date.now() : null, descriptor: state.descriptor,
  profileSource: state.descriptor ? 'sender-metadata' : 'unknown',
}) }).mount('#app')
