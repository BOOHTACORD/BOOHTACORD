import {expect,it,vi} from 'vitest'
import {BaselinePresentation} from './presentation'
it('late viewer must present a new callback after reconnect and cannot reuse previous connection first frame',async()=>{
 vi.stubGlobal('document',{createElement:vi.fn(()=>({}))})
 vi.stubGlobal('window',{setTimeout,clearTimeout})
 const presentation=new BaselinePresentation();let callback:()=>void=()=>{};const video={play:vi.fn(async()=>{}),pause:vi.fn(),requestVideoFrameCallback:vi.fn((next:()=>void)=>{callback=next;return 1}),cancelVideoFrameCallback:vi.fn(),srcObject:{},getVideoPlaybackQuality:()=>({totalVideoFrames:1,droppedVideoFrames:0})}
 const track={kind:'video',attach:vi.fn(),detach:vi.fn()}
 presentation.start(performance.now());presentation.attach(track as any,video as any);callback();await presentation.waitForFirstFrame(1000)
 expect(presentation.snapshot().presentedFrameCallbacks).toBe(1)
 presentation.stop();presentation.start(performance.now())
 expect(presentation.snapshot()).toMatchObject({firstFrameLatencyMs:null,presentedFrameCallbacks:0,presentationTimestamps:[]})
 let resolved=false;const fresh=presentation.waitForFirstFrame(1000).then(value=>{resolved=true;return value});await Promise.resolve();expect(resolved).toBe(false)
 presentation.attach(track as any,video as any);callback();expect(await fresh).toBeGreaterThanOrEqual(0);presentation.stop();vi.unstubAllGlobals()
})

it('new remote publication detaches old output and waits its own frame without old frame reuse',async()=>{
 vi.stubGlobal('document',{createElement:vi.fn(()=>({}))});vi.stubGlobal('window',{setTimeout,clearTimeout})
 const presentation=new BaselinePresentation();let callback=()=>{};const video={play:vi.fn(async()=>{}),pause:vi.fn(),requestVideoFrameCallback:vi.fn((next:()=>void)=>{callback=next;return 1}),cancelVideoFrameCallback:vi.fn(),srcObject:{},getVideoPlaybackQuality:()=>({totalVideoFrames:1,droppedVideoFrames:0})}
 const old={kind:'video',attach:vi.fn(),detach:vi.fn()},fresh={kind:'video',attach:vi.fn(),detach:vi.fn()}
 presentation.start(performance.now());presentation.attach(old as any,video as any);callback();await presentation.waitForFirstFrame(1000)
 presentation.attach(fresh as any,video as any);expect(old.detach).toHaveBeenCalledTimes(1);expect(fresh.attach).toHaveBeenCalledTimes(1);expect(presentation.snapshot()).toMatchObject({firstFrameLatencyMs:null,presentedFrameCallbacks:0,videoAttachmentRevision:2})
 const first=presentation.waitForFirstFrame(1000);callback();expect(await first).toBeGreaterThanOrEqual(0);presentation.stop();vi.unstubAllGlobals()
})
