import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { createPinia } from 'pinia'

import VoiceParticipantVolumes from './VoiceParticipantVolumes.vue'

describe('connected voice room with only the local participant', () => {
  it('shows the self card without an extra empty-remote row', async () => {
    const html = await renderToString(createSSRApp(VoiceParticipantVolumes, {
      error: null,
      participants: [],
      screenStreams: [],
      selectedScreenStreamId: null,
      selfName: 'Оля',
      selfDeafened: false,
      selfMicrophoneMuted: false,
      selfMicrophoneUnavailable: false,
      selfSpeaking: false,
    }).use(createPinia()))

    expect(html).toContain('>Оля</span>')
    expect(html).not.toContain('Оля · вы')
    expect(html).toContain('data-testid="participant-card"')
    expect(html).not.toContain('Другие участники пока не подключены')
  })
})
