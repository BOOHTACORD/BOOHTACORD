import assert from 'node:assert/strict'
import {expect} from '../client_lifecycle/request.mjs'

export function observe() {
  const Native=window.RTCPeerConnection
  window.__ptt={peers:[],incoming:[]}
  window.RTCPeerConnection=new Proxy(Native,{construct(target,args,newTarget){
    const pc=Reflect.construct(target,args,newTarget);window.__ptt.peers.push(pc)
    pc.addEventListener('track',event=>{
      if(event.track.kind!=='audio')return
      const context=new AudioContext(),analyser=context.createAnalyser(),gain=context.createGain()
      analyser.fftSize=2048;gain.gain.value=0
      context.createMediaStreamSource(new MediaStream([event.track])).connect(analyser)
      analyser.connect(gain);gain.connect(context.destination);void context.resume()
      window.__ptt.incoming.push({pc,track:event.track,context,analyser})
    })
    return pc
  }})
}

export async function sample(page) {
  return page.evaluate(async()=>{
    const peers=window.__ptt.peers.filter(pc=>pc.connectionState==='connected')
    let packets=0, rtpBytes=0
    for(const pc of peers)for(const row of (await pc.getStats()).values()){
      if(row.type==='inbound-rtp'&&row.kind==='audio'){packets+=row.packetsReceived??0;rtpBytes+=row.bytesReceived??0}
    }
    let rms=0,tracks=0
    for(const item of window.__ptt.incoming){
      if(item.pc.connectionState!=='connected'||item.track.readyState!=='live')continue
      tracks++;const data=new Float32Array(item.analyser.fftSize);item.analyser.getFloatTimeDomainData(data)
      rms=Math.max(rms,Math.sqrt(data.reduce((sum,x)=>sum+x*x,0)/data.length))
    }
    return {peers:peers.length,packets,rtpBytes,rms,tracks,constructed:window.__ptt.peers.length}
  })
}

export async function audio(sender,receiver,pressed,report,name) {
  const button=sender.getByTestId('voice-dock').getByRole('button',{name:'Микрофон управляется push-to-talk',exact:true})
  if(await button.count())await expect(button).toHaveAttribute('aria-pressed',String(pressed))
  await sender.waitForTimeout(700)
  await expect.poll(async()=>{
    const value=await sample(receiver)
    return value.peers>0&&Number.isFinite(value.rms)&&(pressed?value.rms>.003&&value.packets>0:value.rms<.001)
  },{timeout:12000}).toBe(true)
  const values=[]
  for(let i=0;i<4;i++){values.push(await sample(receiver));await receiver.waitForTimeout(120)}
  assert.ok(values.every(v=>v.peers>0&&Number.isFinite(v.rms)))
  if(pressed)assert.ok(values.some(v=>v.rms>.003&&v.packets>0))
  else assert.ok(values.every(v=>v.rms<.001),'Audio continued after PTT release')
  report.push({name,expected_audio:pressed,observations:values})
}
