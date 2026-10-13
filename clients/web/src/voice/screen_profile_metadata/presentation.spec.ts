import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { screenCaptureLabel, screenEncodingLabel, screenModeLabel, screenTargetLabel, screenTargetSourceLabel } from './presentation'

const fixture = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8')).validDescriptor

describe('screen descriptor presentation', () => {
  it('keeps the requested target distinct from applied capture and encoding limits', () => {
    const descriptor = { ...fixture, requested_profile_id: 'P1080_60', mode: 'motion' as const,
      effective_profile: { ...fixture.effective_profile, capture: { ...fixture.effective_profile.capture, max_fps: 30 } } }
    expect(screenTargetLabel(descriptor.requested_profile_id)).toBe('1080p · 60 FPS')
    expect(screenTargetSourceLabel('sender-metadata')).toBe('Цель передана отправителем')
    expect(screenModeLabel(descriptor.mode)).toBe('Плавность')
    expect(screenCaptureLabel(descriptor)).toContain('до 30 FPS')
    expect(screenEncodingLabel(descriptor)).toContain('Мбит/с')
  })

  it('labels legacy hints as estimates and missing publisher data as unavailable', () => {
    expect(screenTargetLabel(undefined, '1080p · 30 FPS')).toBe('1080p · 30 FPS')
    expect(screenTargetSourceLabel('legacy-track-name')).toBe('Профиль при запуске · имя дорожки')
    expect(screenTargetSourceLabel('unknown')).toBe('Цель не передана отправителем')
    expect(screenModeLabel(undefined)).toBe('Нет данных от отправителя')
    expect(screenCaptureLabel()).toBe('Нет данных от отправителя')
  })
})
