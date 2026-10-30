import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { formatScreenVideoQuality } from './screen_video_quality'

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), 'utf8')
}

describe('screen viewer reference composition', () => {
  it('shows stream identity, truthful target/actual quality, canvas, and a return-to-room action', () => {
    const viewer = source('./ScreenViewer.vue')

    expect(viewer).toContain('screen-stage-label')
    expect(viewer).toContain('selectedStream.participantName')
    expect(viewer).toContain('ScreenReceiverDiagnosticsPanel')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('actualVideoQuality')
    expect(source('./screen_playback_quality.ts')).toContain('Определяем качество…')
    expect(viewer).toContain('participantAudioMessage(deafened)')
    expect(viewer).toContain('Выберите демонстрацию. Загружается только один выбранный поток.')
    expect(viewer).toContain('К участникам')
    expect(viewer).toContain('stream-voice-return')
  })

  it('renders each available publisher as a labelled rail choice', () => {
    const viewer = source('./ScreenViewer.vue') + source('./ScreenViewerRail.vue')
    const styles = source('../design/voice_viewer_reference.css')

    expect(viewer).toContain('screen-cards stream-rail')
    expect(viewer).toContain('screen-preview-placeholder')
    expect(viewer).toContain('participantName')
    expect(viewer).toContain('aria-pressed')
    expect(viewer).toContain('stream.thumbnailUrl')
    expect(viewer).toContain('stream.id === selectedId')
    expect(viewer).toContain('<ScreenViewerParticipantStrip')
    expect(source('./ScreenViewerRail.vue')).not.toContain('Участники ·')
    expect(source('./ScreenViewerParticipantStrip.vue')).toContain('в комнате')
    expect(viewer).toContain('screen-player')
    expect(styles).toContain('.stream-voice-return')
    expect(styles).toContain('min-width: 152px')
    expect(styles).toContain('max-width: 200px')
  })


  it('labels the owner screen preview and keeps its video muted', () => {
    const viewer = source('./ScreenViewer.vue') + source('./ScreenViewerRail.vue')

    expect(viewer).toContain("selectedStream.isLocal ? 'Ваш экран'")
    expect(viewer).toContain(':muted="selectedStream?.isLocal ?? false"')
    expect(source('./screen_audio_copy.ts')).toContain('Предпросмотр собственного экрана без звука')
    expect(viewer).toContain('ScreenViewerAudioControl v-if="selectedStream.hasAudio && !selectedStream.isLocal"')
    expect(source('./ScreenViewerAudioControl.vue')).toContain('v-if="adjustable"')
    expect(source('../conversation/ConversationPane.vue')).toContain(':deafened="selfDeafened"')
    expect(viewer).toContain('data-testid="stream-rail"')
    expect(viewer).toContain('data-testid="stream-select"')
  })

  it('names the selected stream in the stable voice-room header', () => {
    const pane = source('../conversation/ConversationPane.vue')

    expect(pane).toContain('selectedScreenName && voiceIsActive ?')
    expect(pane).toContain('${screenViewerCards.length} трансляции')
  })

  it('shows dimensions only after real video metadata arrives', () => {
    expect(formatScreenVideoQuality({ videoWidth: 1920, videoHeight: 1080 })).toBe('1920 × 1080 · FPS не определена')
    expect(formatScreenVideoQuality({ videoWidth: 1920, videoHeight: 1080 }, 1)).toBe('1920 × 1080 · 1 FPS у зрителя')
    expect(formatScreenVideoQuality({ videoWidth: 1920, videoHeight: 1080 }, 0)).toBe('1920 × 1080 · 0 FPS у зрителя')
    expect(formatScreenVideoQuality({ videoWidth: 0, videoHeight: 0 })).toBe('Определяем качество…')
    expect(source('./ScreenViewer.vue')).toContain('@loadedmetadata="refreshVideoQuality"')
    expect(source('./ScreenViewer.vue')).toContain('@resize="refreshVideoQuality"')
  })

  it('contains portrait video within the grid stage instead of clipping its intrinsic minimum size', () => {
    const styles = source('../design/voice.css')
    const playerRules = [...styles.matchAll(/\.screen-player\s*\{([^}]*)\}/g)]
      .map((match) => match[1])
      .join(';')

    expect(playerRules).toContain('min-width: 0')
    expect(playerRules).toContain('min-height: 0')
    expect(playerRules).toContain('object-fit: contain')
  })

  it('closes an ended selected stream and waits for an explicit new selection', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const viewer = source('./ScreenViewer.vue')

    expect(pane).toContain('screenViewerEnded')
    expect(pane).toContain('screenViewerCards.length || selectedScreenStreamId || screenViewerEnded')
    expect(pane).toContain(':ended="screenViewerEnded"')
    expect(pane).toContain('v-show="selectedScreenStreamId !== null"')
    expect(viewer).toContain('Демонстрация завершена.')
  })

  it('shows a waiting-frame state until the selected publisher produces decoded video', () => {
    const viewer = source('./ScreenViewer.vue')

    expect(viewer).toContain('videoReady')
    expect(viewer).toContain('Получаем первый кадр демонстрации…')
    expect(viewer).toContain('@loadeddata="markVideoReady"')
    expect(viewer).toContain('@emptied="resetVideoFrame"')
    expect(viewer).toContain('markScreenSelected(video.value)')
    expect(viewer).toContain('resetVideoFrame()')
    expect(source('./viewer_diagnosis/Panel.vue')).toContain('selectedAt.value=Date.now();now.value=selectedAt.value;emit(\'retry\')')
    expect(source('./ScreenViewer.vue')).toContain(':publisher-paused="videoPaused || Boolean(selectedStream.videoMuted)"')
  })

  it('offers a gesture retry when audio autoplay is blocked independently of video', () => {
    const viewer = source('./ScreenViewer.vue')
    expect(viewer).toContain('audioPlaybackBlocked.value=true')
    expect(viewer).toContain('videoPlaybackBlocked.value || audioPlaybackBlocked.value')
    expect(viewer).toContain('audio.value?.play()')
    expect(viewer).toContain(':autoplay-blocked="playbackBlocked"')
    expect(viewer).toContain('@retry="retry(false)"')
    expect(viewer).toContain('@audio="emit(\'toggleAudio\');audioPlaybackBlocked && playFromGesture()"')
    expect(viewer).toContain('@toggle="emit(\'toggleAudio\');audioPlaybackBlocked&&playFromGesture()"')
  })
})
