import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  try { return readFileSync(new URL(relativePath, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('voice participant screen actions', () => {
  it('keeps the participant room visible until a real screen is selected', () => {
    const pane = source('../conversation/ConversationPane.vue')

    expect(pane).toContain('screenViewerCards.length || selectedScreenStreamId || screenViewerEnded')
    expect(pane).toContain('v-show="selectedScreenStreamId !== null"')
    expect(pane).toContain(`!voiceIsActive || voiceState === 'LEAVING' || !selectedScreenStreamId`)
    expect(pane).toContain('@watch-screen="watchScreen"')
    expect(pane).toContain('ref="screenViewerRef"')
    expect(pane).toContain('@clear="clearScreenPreview"')
    expect(pane).toContain('dismissLocalPreview()')
  })

  it('embeds screen previews in stream cards and gives voice-only cards the same preview area', () => {
    const participants = source('./VoiceParticipantVolumes.vue')
    const preview = source('./ParticipantScreenPreview.vue')
    const styles = source('../design/voice_participant_screens.css')

    expect(participants).toContain('screenForParticipant')
    expect(participants).toContain('<ParticipantScreenPreview')
    expect(participants).toContain('participant-voice-placeholder')
    expect(participants).toContain('participant--voice-only')
    expect(participants).not.toContain('Смотреть экран')
    expect(preview).toContain(':aria-pressed="selected === true"')
    expect(styles).toContain('.participant-screen-preview')
    expect(styles).toContain('aspect-ratio: 16 / 9')
  })

  it('shows a Discord-style loading message instead of initials until a screen thumbnail arrives', () => {
    const preview = source('./ParticipantScreenPreview.vue')
    const rail = source('./ScreenViewerRail.vue')

    expect(preview).toContain('Трансляция идёт')
    expect(rail).toContain('Трансляция идёт')
    expect(preview).toContain('Предпросмотр скоро появится')
    expect(preview).not.toContain('initials')
    expect(rail).not.toContain('initials')
    expect(preview).toContain('screen.thumbnailUrl')
  })

  it('resolves a watch action by the verified LiveKit participant identity', async () => {
    const { findParticipantScreen } = await import('./find_participant_screen')
    const streams = [
      { id: 'alice:screen', participantId: 'alice', participantName: 'Алиса', hasAudio: true },
      { id: 'bob:screen', participantId: 'bob', participantName: 'Боб', hasAudio: false },
    ]

    expect(findParticipantScreen(streams, 'bob')?.id).toBe('bob:screen')
    expect(findParticipantScreen(streams, 'offline')).toBeNull()
  })
})
