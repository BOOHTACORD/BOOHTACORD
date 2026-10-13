import { createApp, h, reactive } from 'vue'
import ScreenReceiverDiagnosticsPanel from '../../src/voice/ScreenReceiverDiagnosticsPanel.vue'
import '../../src/style.css'
import fixture from '../../../../contracts/screen-share-profile-v1.fixtures.json'
import type { ScreenShareDescriptorV1 } from '../../src/voice/screen_profile_metadata/types'

const state = reactive({ descriptor: fixture.validDescriptor as ScreenShareDescriptorV1 | undefined })
Object.assign(window, {
  qaDescriptorState: (kind: 'sharing' | 'updating' | 'idle' | 'missing') => {
    state.descriptor = kind === 'missing' ? undefined : { ...fixture.validDescriptor as ScreenShareDescriptorV1, publisher_state: kind }
  },
})
createApp({ render: () => h(ScreenReceiverDiagnosticsPanel, {
  actualVideoQuality: 'Нет данных', hasAudio: false, isLocal: false,
  metrics: null, sampledAt: null, descriptor: state.descriptor,
  profileSource: state.descriptor ? 'sender-metadata' : 'unknown',
}) }).mount('#app')
