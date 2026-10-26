import type { RealtimeEvent } from '../../realtime/realtime_client'
export interface SocialHint { kind:'CHANNEL'|'DIRECT_MESSAGE';conversationId:string;messageId:string;action:'reactions'|'pins' }
type Listener = (hint:SocialHint|null)=>void|Promise<void>
const listeners = new Set<Listener>()
export const isSocialHint = (kind:string):boolean => ['message.reactions_updated','message.pins_updated','direct_message.reactions_updated'].includes(kind)
export function subscribeSocialHints(listener:Listener):()=>void { listeners.add(listener);return ()=>{listeners.delete(listener)} }
function notify(hint:SocialHint|null):void { for (const listener of listeners) { try { const work=listener(hint); if(work) void work.catch(()=>{}) } catch { /* A disposed UI observer must not break session delivery. */ } } }
export function notifySocialRecovery():void { notify(null) }
export function notifyLocalPinChange(conversationId:string,messageId:string):void { notify({kind:'CHANNEL',conversationId,messageId,action:'pins'}) }
export function notifySocialHint(event:RealtimeEvent):void {
  if (!isSocialHint(event.kind)) return
  const direct = event.kind==='direct_message.reactions_updated'
  const conversationId = event.payload[direct?'direct_message_id':'channel_id'], messageId = event.payload.message_id
  if (typeof conversationId==='string' && typeof messageId==='string') notify({kind:direct?'DIRECT_MESSAGE':'CHANNEL',conversationId,messageId,action:event.kind==='message.pins_updated'?'pins':'reactions'})
}

// Durable delivery awaits observer refreshes. Local UI notifications keep the
// best-effort path above; a remote failed refresh must not become a cursor.
function notifyApplied(hint:SocialHint|null):void|Promise<void> {
  const pending:Promise<void>[]=[]
  for(const listener of [...listeners]) {
    try { const work=listener(hint); if(work) pending.push(work) }
    catch(cause) { pending.push(Promise.reject(cause)) }
  }
  if(pending.length) return Promise.all(pending).then(()=>{})
}
export function applySocialRecovery():void|Promise<void> { return notifyApplied(null) }
export function applySocialHint(event:RealtimeEvent):void|Promise<void> {
  if(!isSocialHint(event.kind)) return
  const direct=event.kind==='direct_message.reactions_updated'
  const conversationId=event.payload[direct?'direct_message_id':'channel_id'],messageId=event.payload.message_id
  if(typeof conversationId==='string'&&typeof messageId==='string') return notifyApplied({kind:direct?'DIRECT_MESSAGE':'CHANNEL',conversationId,messageId,action:event.kind==='message.pins_updated'?'pins':'reactions'})
}
