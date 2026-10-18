import { expect,it } from 'vitest'
import { diagnose, firstFrameTimeoutMs, resumeFirstFrameDeadline, shouldAutomaticallyRecover } from './model'
const base={selected:true,ended:false,visible:true,local:false,hasAudio:true,videoReady:true,presentedFps:30,sampledAt:10000,selectedAt:0,now:11000}
it('distinguishes no first frame, frozen video, absent audio and stale observations',()=>{
  expect(diagnose({...base,videoReady:false}).state).toBe('no_first_frame')
  expect(diagnose({...base,presentedFps:0}).state).toBe('frozen')
  expect(diagnose({...base,hasAudio:false}).state).toBe('no_audio')
  expect(diagnose({...base,sampledAt:0}).state).toBe('stale_metrics')
  expect(diagnose({...base,sampledAt:null}).state).toBe('stale_metrics')
})
it('keeps a missing-audio diagnosis stable while receiver samples are absent or stale',()=>{
  for (const sampledAt of [null,0,10000]) {
    expect(diagnose({...base,hasAudio:false,sampledAt}).state).toBe('no_audio')
  }
  expect(diagnose({...base,hasAudio:false,sampledAt:null,presentedFps:0}).state).toBe('frozen')
})
it('treats a silent local preview as expected and offers no audio fix action',()=>{
  expect(diagnose({...base,local:true,hasAudio:false})).toMatchObject({
    state:'playing',message:'Предпросмотр без звука.',action:'none',label:'',
  })
})
it('does not claim playback failure in a hidden tab or before the initial grace interval',()=>{
  expect(diagnose({...base,visible:false,presentedFps:0}).state).toBe('background')
  expect(diagnose({...base,videoReady:false,selectedAt:10000}).state).toBe('connecting')
  expect(diagnose({...base,presentedFps:null}).state).toBe('playing')
})
it('reports a muted sender without offering viewer-side recovery',()=>{
  expect(diagnose({...base,publisherPaused:true,videoReady:false}).state).toBe('publisher_paused')
  expect(diagnose({...base,publisherPaused:true,videoReady:false}).action).toBe('none')
})
it('uses the contract observation timeout and preserves remaining wait across a suspension',()=>{
  expect(firstFrameTimeoutMs).toBe(5000)
  expect(shouldAutomaticallyRecover({...base,selectedAt:0,now:firstFrameTimeoutMs-1,videoReady:false})).toBe(false)
  expect(resumeFirstFrameDeadline(1000,3000,9000)).toBe(7000)
  expect(shouldAutomaticallyRecover({...base,selectedAt:7000,now:11999,videoReady:false})).toBe(false)
  expect(shouldAutomaticallyRecover({...base,selectedAt:7000,now:12000,videoReady:false})).toBe(true)
  expect(diagnose({...base,selectedAt:0,now:5000,videoReady:false}).action).toBe('retry')
})
it('recovers immediately only for a live visible unpaused remote subscription failure',()=>{
  expect(diagnose({...base,subscriptionFailed:true}).state).toBe('subscription_failed')
  expect(diagnose({...base,subscriptionFailed:true}).action).toBe('retry')
  expect(shouldAutomaticallyRecover({...base,now:10000,subscriptionFailed:true,videoReady:false})).toBe(true)
  expect(shouldAutomaticallyRecover({...base,now:10000,subscriptionFailed:true,videoReady:true,presentedFps:0})).toBe(false)
  for(const blocked of [
    {visible:false}, {ended:true}, {local:true}, {publisherPaused:true}, {autoplayBlocked:true},
    {automaticRecoveryAttempted:true}, {videoReady:true},
  ]) expect(shouldAutomaticallyRecover({...base,now:10000,subscriptionFailed:true,...blocked})).toBe(false)
})
