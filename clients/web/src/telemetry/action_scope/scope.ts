import { context, createContextKey, ROOT_CONTEXT,SpanKind, SpanStatusCode, trace, type Context, type Span, type Tracer, type Link } from '@opentelemetry/api'
import { diagnosticId, telemetrySession, type TelemetrySession, type SessionSnapshot } from './session'
import { fields } from '../flow_contract/generated'
export type FlowName = 'startup'|'session.restore'|'auth.login'|'message.send'|'message.render'|'voice.join'|'voice.leave'|'voice.reconnect'|'realtime.connect'|'realtime.reconnect'|'realtime.process'|'screen.share.start'|'screen.share.stop'|'screen.view'
export type Outcome = 'success'|'failed'|'cancelled'|'rejected'|'timeout'|'superseded'
export const actionKey=createContextKey('boohtacord/action')
export class ActionScope {
 readonly id: string
 readonly snapshot: SessionSnapshot
 readonly span: Span
 readonly context: Context
 private ended=false
 private completion=new Set<()=>void>()
 get complete():boolean {return this.ended}
 onFinish(call:()=>void):()=>void {
  if(this.ended){try{call()}catch{};return ()=>{}}
  this.completion.add(call);return ()=>this.completion.delete(call)
 }
 private stage='intent'
 private started=Date.now()
 private timer: ReturnType<typeof setTimeout>
 private unsubscribe:()=>void
 constructor(readonly name: FlowName, private tracer: Tracer=trace.getTracer('boohtacord/web'),
  private session: TelemetrySession=telemetrySession, readonly attempt=1, id=diagnosticId(), private links:Link[]=[]) {
  this.id=id;this.snapshot=session.snapshot()
  this.span=tracer.startSpan(name,{kind:SpanKind.INTERNAL,startTime:this.started,attributes:this.attributes('terminal','unknown'),links},ROOT_CONTEXT)
  this.context=trace.setSpan(ROOT_CONTEXT,this.span).setValue(actionKey,this)
  this.emit('start','unknown')
  this.timer=setTimeout(()=>this.finish('timeout','deadline'),120000)
  this.unsubscribe=session.onReset(()=>this.finish('superseded','generation_changed'))
 }
 attributes(record: string,outcome: string): Record<string,string|number> {
  return {'app.schema.version':1,'app.visit.id':this.snapshot.visit,'app.flow.id':this.id,'app.flow.name':this.name,
   'app.flow.attempt':this.attempt,'app.flow.stage':this.stage,'app.flow.record':record,'app.flow.outcome':outcome,
   'app.provenance':'client_observed',...(this.snapshot.binding?{'session.id':this.snapshot.binding}:{}),
   ...(typeof __APP_VERSION__!=='undefined'?{'app.client.version':__APP_VERSION__}:{}),
   ...(this.snapshot.media?{'app.media.session.id':this.snapshot.media}:{})}
 }
 private emit(record: string,outcome: string): void {
  this.tracer.startSpan(this.name,{kind:SpanKind.INTERNAL,attributes:this.attributes(record,outcome),links:this.links},this.context).end()
 }
 within<R>(call:()=>R):R {
  if(this.session.current(this.snapshot)&&!this.ended)return context.with(this.context,call)
  const ambient=activeAction()
  if(!ambient||(!ambient.complete&&ambient.session.current(ambient.snapshot)))return call()
  return context.with(ROOT_CONTEXT,call)
 }
 step(stage: string): void {
  if(this.ended || !this.session.current(this.snapshot) || !fields['app.flow.stage'].values?.includes(stage))return
  this.stage=stage;this.emit('checkpoint','unknown')
 }
 finish(outcome: Outcome,reason='none'): void {
  if(this.ended)return
  this.ended=true;clearTimeout(this.timer)
  this.unsubscribe?.()
  for(const call of this.completion){try{call()}catch{}}
  this.completion.clear()
  if (!this.session.current(this.snapshot)) {this.span.end();return}
  this.span.setAttributes(this.attributes('terminal',outcome))
  if(fields['app.flow.reason'].values?.includes(reason))this.span.setAttribute('app.flow.reason',reason)
  if(outcome==='failed'||outcome==='timeout'||outcome==='rejected')this.span.setStatus({code:SpanStatusCode.ERROR})
  this.span.end(Math.min(Date.now(),this.started+120000))
 }
 cancel():void {this.finish('cancelled')}
 retry():ActionScope {
  const same=this.session.current(this.snapshot)&&this.attempt<20
  return new ActionScope(this.name,this.tracer,this.session,same?this.attempt+1:1,same?this.id:diagnosticId(),same?this.links:[])
 }
}
export function activeAction(): ActionScope | undefined { return context.active().getValue(actionKey) as ActionScope|undefined }

