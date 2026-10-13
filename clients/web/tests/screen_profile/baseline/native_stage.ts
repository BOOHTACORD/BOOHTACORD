import {ScreenBaselineSession} from './session'
import {presentationMetrics,decodedP05Fps,frameSequenceMetrics} from './metrics'
const session=new ScreenBaselineSession()
function nativeViewerSample(snapshot:Awaited<ReturnType<ScreenBaselineSession['snapshot']>>){
 const {baselineProfileId,userAgent,source,captureSettings,generatedFrames,requestedSyntheticFps,generatedFrameElapsedMs,outbound,firstFrameLatencyMs,...sample}=snapshot
 return {...sample,source:'external-native-owned-window-fixture',captureSettings:null,generatedFrames:null,requestedSyntheticFps:null,generatedFrameElapsedMs:null,sourceCounterReason:'Viewer has no source capture counter; joined native receipt required',roomConnectionToFirstCallbackMs:firstFrameLatencyMs}
}
;(window as any).nativeStage={
 async connect(credential:{url:string,token:string}){session.configure({...credential,role:'viewer',numberedSynthetic:true});await session.connect()},
 firstFrame:()=>session.waitForFirstFrame(60000),
 sample:async()=>nativeViewerSample(await session.snapshot()),
 async collect(duration:number){
  const samples=await session.collectSamples(duration,1000),start=samples[0],end=samples.at(-1)!
  return {samples: samples.map(nativeViewerSample),sampleDurationMs:end.monotonicMs-start.monotonicMs,decodedP05Fps:decodedP05Fps(samples),presentation:presentationMetrics(samples.slice(1).flatMap(s=>s.presentationTimestamps),start.monotonicMs,end.monotonicMs),sequence:frameSequenceMetrics(samples.slice(1).flatMap(s=>s.presentedFrameIds)),provenance:'Headless Chromium rVFC+numbered synthetic marker, not physical compositor scanout',thresholdClaims:false}
 },
 metadata:(owner:Parameters<ScreenBaselineSession['metadataSnapshot']>[0],parse:Parameters<ScreenBaselineSession['metadataSnapshot']>[1])=>session.metadataSnapshot(owner,parse),
 stop:()=>session.stop(),
 capabilities(){
  return {sender:RTCRtpSender.getCapabilities('video')?.codecs.map(c=>({mimeType:c.mimeType,clockRate:c.clockRate,fmtp:c.sdpFmtpLine?.split(';').map(p=>p.trim()).filter(p=>/^(profile-level-id|packetization-mode|level-asymmetry-allowed)=([0-9a-f]{1,6})$/i.test(p))??[]}))??[],receiver:RTCRtpReceiver.getCapabilities('video')?.codecs.map(c=>({mimeType:c.mimeType,clockRate:c.clockRate,fmtp:c.sdpFmtpLine?.split(';').map(p=>p.trim()).filter(p=>/^(profile-level-id|packetization-mode|level-asymmetry-allowed)=([0-9a-f]{1,6})$/i.test(p))??[]}))??[]}
 }
}
