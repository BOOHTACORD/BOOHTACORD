import type { Span, Context } from '@opentelemetry/api'
import type { SpanProcessor, ReadableSpan } from '@opentelemetry/sdk-trace-base'
import { ProtobufTraceSerializer } from '@opentelemetry/otlp-transformer'
import { telemetrySession, type TelemetrySession, type SessionSnapshot } from '../action_scope/session'
import { apiBaseUrl } from '../../config/runtime'
import { recordExportHealth } from './health'
export interface ExportStatus {queued:number;accepted:number;rejected:number;dropped:number;retried:number;lastAcceptedAt:number|null}
export class SessionProcessor implements SpanProcessor {
 readonly status:ExportStatus={queued:0,accepted:0,rejected:0,dropped:0,retried:0,lastAcceptedAt:null}
 private queue:ReadableSpan[]=[]
 private owners=new WeakMap<object,SessionSnapshot>()
 private busy:Promise<void>|null=null
 private stopped=false
 private active:AbortController|null=null
 private timer:ReturnType<typeof setInterval>
 private unsubscribe:()=>void
 constructor(private session:TelemetrySession=telemetrySession,private send:typeof fetch=globalThis.fetch.bind(globalThis)) {
  this.unsubscribe=session.onReset(()=>{this.active?.abort();this.status.dropped+=this.queue.length;this.queue=[];this.status.queued=0})
  this.timer=setInterval(()=>{recordExportHealth(this.session,this.status);void this.forceFlush()},5000)
 }
 onStart(span:Span,_parent:Context):void {
  const owner=this.session.snapshot();this.owners.set(span,owner)
  if(owner.binding)span.setAttribute('session.id',owner.binding)
 }
 onEnd(span:ReadableSpan):void {
  const owner=this.owners.get(span)
  if(this.stopped||!owner?.binding||!this.session.current(owner)||this.queue.length>=128){this.status.dropped++;return}
  this.queue.push(span);this.status.queued=this.queue.length
 }
 forceFlush():Promise<void> {
  if(this.busy)return this.busy
  this.busy=this.flush().catch(()=>{}).finally(()=>{this.busy=null})
  return this.busy
 }
 private async flush():Promise<void> {
  const owner=this.session.snapshot(),origin=typeof window==='undefined'?'https://example.test':window.location.origin
  if(!owner.binding||this.stopped)return
  const spans=this.queue.splice(0,16);this.status.queued=this.queue.length
  if(!spans.length)return
  const body=ProtobufTraceSerializer.serializeRequest(spans)
  if(!body||body.length>262144){this.status.dropped+=spans.length;return}
  for(let attempt=0;attempt<=2;attempt++) {
   if(!this.session.current(owner)||this.stopped){this.status.dropped+=spans.length;return}
   let response:Response|undefined
   const active=new AbortController();this.active=active
   try {response=await this.send(origin+apiBaseUrl+'/telemetry/traces',{method:'POST',credentials:'same-origin',
    headers:{...(owner.installation?{'X-Installation-ID':owner.installation}:{}),'Content-Type':'application/x-protobuf','X-Client-Platform':'web','X-Telemetry-Session':owner.binding},
    body:body as BodyInit,signal:AbortSignal.any([active.signal,AbortSignal.timeout(3000)])})}catch{}
   finally{if(this.active===active)this.active=null}
   if(!this.session.current(owner)||this.stopped){this.status.dropped+=spans.length;return}
   if(response?.status===202) {
    const count=(name:string,fallback:number)=>{const value=Number(response!.headers.get(name)??fallback);return Number.isInteger(value)&&value>=0&&value<=spans.length?value:0}
    const accepted=count('X-Telemetry-Accepted',spans.length),rejected=count('X-Telemetry-Rejected',0)
    this.status.accepted+=accepted;this.status.rejected+=rejected
    if(accepted>0)this.status.lastAcceptedAt=Date.now();return
   }
   const retry=!response||response.status===429||response.status>=500
   if(!retry||attempt===2){this.status.dropped+=spans.length;return}
   this.status.retried++
   const retryAfter=Number(response?.headers.get('Retry-After'))
   await new Promise<void>(resolve=>setTimeout(resolve,Math.min(2000,Math.max(100,Number.isFinite(retryAfter)?retryAfter*1000:250*(attempt+1)))+Math.floor(Math.random()*100)))
  }
 }
 async shutdown():Promise<void> {this.stopped=true;this.active?.abort();clearInterval(this.timer);this.unsubscribe();this.status.dropped+=this.queue.length;this.queue=[];this.status.queued=0}
}

