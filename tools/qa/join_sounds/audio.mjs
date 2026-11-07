export function wav() {
  const bytes = Buffer.alloc(44+24000)
  bytes.write('RIFF',0);bytes.writeUInt32LE(bytes.length-8,4);bytes.write('WAVEfmt ',8);bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(1,22);bytes.writeUInt32LE(24000,24);bytes.writeUInt32LE(48000,28);bytes.writeUInt16LE(2,32);bytes.writeUInt16LE(16,34);bytes.write('data',36);bytes.writeUInt32LE(24000,40)
  for(let i=0;i<12000;i++) bytes.writeInt16LE(Math.round(Math.sin(i*2*Math.PI*440/24000)*15000),44+i*2)
  return bytes
}
export function observeCues() {
  const urls = new Map(), create = URL.createObjectURL.bind(URL), play = HTMLMediaElement.prototype.play
  window.__qaCues = []
  URL.createObjectURL = blob => {const url=create(blob);urls.set(url,blob.type);return url}
  HTMLMediaElement.prototype.play = function(...args) {
    const cue = this instanceof HTMLAudioElement && urls.has(this.src)
    return play.apply(this,args).then(() => {if(cue)window.__qaCues.push(urls.get(this.src))})
  }
}
export function syntheticScreen() {
  navigator.mediaDevices.getDisplayMedia = async () => {
    const canvas=document.createElement('canvas');canvas.width=640;canvas.height=360
    const drawing=canvas.getContext('2d');let n=0
    const timer=setInterval(()=>{drawing.fillStyle=++n%2?'#163d62':'#1d6144';drawing.fillRect(0,0,640,360)},33)
    const stream=canvas.captureStream(30); stream.getVideoTracks()[0].addEventListener('ended',()=>clearInterval(timer),{once:true})
    return stream
  }
}
