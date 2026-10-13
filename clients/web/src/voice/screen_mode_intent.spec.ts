import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it, vi } from 'vitest'
import ScreenShareQualityOptions from './ScreenShareQualityOptions.vue'
import { selectScreenQualityMode } from './screen_share_quality_selection'
import { ScreenProfileMetadataPublisher } from './screen_profile_metadata/publisher'
import { useScreenShareSetup } from '../workspace/screen_share_setup'

describe('explicit content intent across screen profile boundaries', () => {
  it('metadata keeps explicit motion30 and text60 without FPS inference', async () => {
    const values: any[] = []
    const publisher = new ScreenProfileMetadataPublisher({ setAttributes: async value => {
      values.push(JSON.parse(value['boohtacord.screen-share.v1']!))
    } }, { originId: 'https://fixture.test', accountId: 'fixture-account', roomId: 'fixture-room' })
    await publisher.publish('P1080_30', 1, { width: 1920, height: 1080 },
      [{ maxBitrate: 5000000, maxFramerate: 30 }], 'motion')
    await publisher.publish('P1080_60', 1, { width: 1920, height: 1080 },
      [{ maxBitrate: 8000000, maxFramerate: 60 }], 'text')
    expect(values.map(value => value.mode)).toEqual(['motion', 'text'])
  })

  it('changing scenario preserves requested frame rate', () => {
    expect(selectScreenQualityMode({ mode: 'text', resolution: 1080, frameRate: 30 }, 'motion'))
      .toEqual({ mode: 'motion', resolution: 1080, frameRate: 30 })
    expect(selectScreenQualityMode({ mode: 'motion', resolution: 1080, frameRate: 60 }, 'text'))
      .toEqual({ mode: 'text', resolution: 1080, frameRate: 60 })
  })

  it('both scenarios offer existing FPS choices', async () => {
    for (const mode of ['motion', 'text'] as const) {
      const html = await renderToString(createSSRApp(ScreenShareQualityOptions,
        { mode, resolution: 1080, frameRate: 30 }))
      for (const fps of [15, 30, 60]) expect(html).toContain(`value="${fps}"`)
    }
  })

  it('workspace forwards the chosen scenario alongside the unchanged profile', () => {
    const start = vi.fn(async () => undefined)
    const setup = useScreenShareSetup(() => 'IDLE', start, 'fixture-account', 'https://fixture.test')
    setup.confirmScreenShare('P1080_60', 'text')
    expect(start).toHaveBeenCalledWith('P1080_60', 'text')
  })
})
