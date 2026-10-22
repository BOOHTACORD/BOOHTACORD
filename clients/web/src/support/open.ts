import { ref } from 'vue'
import { telemetrySession } from '../telemetry/action_scope/session'
import { openDirectMessage } from '../direct_message/direct_message_candidate_client'
import type { DirectMessageRequest } from '../direct_message/direct_message_client'
import { unavailableSupport, type SupportContact } from './contact'
interface Ports {refresh(request?: DirectMessageRequest): Promise<void>; contact(): SupportContact; has(id:string): boolean}
export function createSupportOpener(ports: Ports) {
 const supportOpening=ref(false), supportNotice=ref<string|null>(null)
 let generation=0
 function invalidate(): void {generation++;supportOpening.value=false;supportNotice.value=null}
 async function openSupport(request?: DirectMessageRequest): Promise<string|null> {
  if (supportOpening.value) return null
  const sequence=++generation, owner=telemetrySession.snapshot()
  const current=()=>sequence===generation && telemetrySession.current(owner)
  supportOpening.value=true;supportNotice.value=null
  try {
   await ports.refresh(request)
   if (!current()) return null
   const contact=ports.contact()
   if (contact.state!=='available' || !contact.accountId) {supportNotice.value=unavailableSupport(contact);return null}
   const opened=await openDirectMessage(contact.accountId,request)
   if (!current()) return null
   await ports.refresh(request)
   if (!current()) return null
   const now=ports.contact()
   if (now.state!=='available'||now.accountId!==contact.accountId||now.revision!==contact.revision) {
    supportNotice.value='Контакт поддержки изменился. Старые диалоги сохраняют прежних участников. Нажмите ? ещё раз.';return null
   }
   if (!ports.has(opened.id)) {supportNotice.value='Не удалось открыть поддержку. Обновите список и повторите.';return null}
   return opened.id
  } catch {if(current())supportNotice.value='Не удалось открыть поддержку этого сервера. Повторите позже.';return null}
  finally {if(sequence===generation)supportOpening.value=false}
 }
 return {supportOpening,supportNotice,openSupport,invalidate}
}
