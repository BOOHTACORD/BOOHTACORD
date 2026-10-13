import { expect, test } from '@playwright/test'
import { decodeFrameMarker, encodeFrameMarker } from './frame_marker'

test('numbered synthetic frames survive marker encoding and decoding', () => {
  for (const frame of [0, 1, 42, 2048, 65535]) {
    const luma = encodeFrameMarker(frame).map(bit => bit ? 255 : 0)
    expect(decodeFrameMarker(luma)).toBe(frame & 0xfff)
  }
  expect(decodeFrameMarker([0, 255, 0])).toBeNull()
})

test('scaled displaced synthetic marker retains its frame ID without assuming capture geometry', async ({page}) => {
 await page.goto('/tests/screen_profile/fixture.html')
 const values=await page.evaluate(async()=>{
  const {drawFrameMarker,readFrameMarker}=await import('/tests/screen_profile/baseline/frame_marker.ts')
  return [.5,1,1.5].map(scale=>{
   const source=document.createElement('canvas');source.width=640;source.height=360
   Object.defineProperties(source,{videoWidth:{value:640},videoHeight:{value:360}})
   const context=source.getContext('2d')!;context.fillStyle='#102030';context.fillRect(0,0,640,360)
   context.translate(52,70);context.scale(scale,scale);context.translate(-32,-128);drawFrameMarker(context,42)
   return readFrameMarker(source as unknown as HTMLVideoElement,document.createElement('canvas'))
  })
 })
 expect(values).toEqual([42,42,42])
})


test('native viewer provenance leaves unobserved source counters unknown', async ({page}) => {
 await page.goto('/tests/screen_profile/native_stage.html')
 const sample=await page.evaluate(()=>(window as any).nativeStage.sample())
 expect(typeof sample.monotonicMs).toBe('number')
 expect(sample.inbound.layers).toEqual([])
 expect(sample.source).toBe('external-native-owned-window-fixture')
 expect(sample.generatedFrames).toBeNull()
 expect(sample.generatedFrameElapsedMs).toBeNull()
 expect(sample.sourceCounterReason).toBe('Viewer has no source capture counter; joined native receipt required')
 expect(sample).not.toHaveProperty('outbound')
 expect(sample).not.toHaveProperty('baselineProfileId')
})
