export interface SupportContact { state: 'available' | 'not_configured' | 'unavailable' | 'self'; revision: number; accountId?: string; productAccountId?:string; mode?: 'product'|'local'|'disabled'; noticeVersion?:number; repositoryPublic?:boolean; consentRequired?:boolean }
export const noSupport: SupportContact = { state: 'not_configured', revision: 0 }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
export function parseSupportContact(value: unknown): SupportContact {
 if (!value || typeof value !== 'object' || Array.isArray(value)) return {...noSupport}
 const v = value as Record<string, unknown>
 if (!Number.isSafeInteger(v.revision) || (v.revision as number) < 0) return {state:'unavailable', revision:0}
 const revision = v.revision as number
 const product=typeof v.product_account_id==='string'&&uuid.test(v.product_account_id)?{productAccountId:v.product_account_id,repositoryPublic:v.repository_public!==false}:{}
 if(v.mode==='product') {
  const notice=Number.isSafeInteger(v.notice_version)&&(v.notice_version as number)>0 ? v.notice_version as number : 0
  const accountId=typeof v.account_id==='string'&&uuid.test(v.account_id)?v.account_id:undefined
  return {...product,state:v.state==='available'&&accountId&&notice>0?'available':'unavailable',revision,accountId,mode:'product',noticeVersion:notice,repositoryPublic:v.repository_public!==false,consentRequired:notice===0||v.consent_required!==false}
 }
 if (v.state === 'available' && revision > 0 && typeof v.account_id === 'string' && uuid.test(v.account_id)) return {...product,state:'available', revision, accountId:v.account_id}
 if (v.state === 'self' || v.state === 'not_configured' || v.state === 'unavailable') return {...product,state:v.state, revision}
 return {state:'unavailable', revision}
}
export function isProductSupportPeer(peer:string,contact:SupportContact):boolean {return contact.productAccountId===peer||contact.mode==='product'&&contact.accountId===peer}
export function isCurrentSupportPeer(peer:string,contact:SupportContact):boolean {return contact.state==='available'&&contact.accountId===peer}
export function isSupportPeer(peer: string, contact: SupportContact): boolean { return isProductSupportPeer(peer,contact)||(contact.state === 'available' && contact.accountId === peer) }
export function supportPresentation(item: {otherParticipantId: string; otherParticipantDisplayName: string}, contact: SupportContact): string {
 return isSupportPeer(item.otherParticipantId, contact) ? 'Поддержка' : item.otherParticipantDisplayName
}
export const supportPrivacy = 'Сообщения видит назначенная поддержка этого сервера. Для исправления ошибок команда может создать публичную техническую задачу без вашего текста и файлов.'
export const publicSupportPrivacy = 'Публичная поддержка: текст и файлы будут доступны всем в GitHub Egkurilov/BOOHTACORD. Не отправляйте пароли и личные данные. Первое сообщение создаёт issue, следующие — комментарии. Изменение или удаление здесь не удаляет публикацию в GitHub.'
export function supportPrivacyNotice(contact:SupportContact,peer=''):string {return contact.mode!=='product'&&!isProductSupportPeer(peer,contact)?supportPrivacy:contact.repositoryPublic!==false?publicSupportPrivacy:'Текст и файлы передаются поддержке BOOHTACORD в GitHub Egkurilov/BOOHTACORD. Доступ определяется правами репозитория. Изменение или удаление здесь не удаляет публикацию в GitHub.'}
export const supportPrompt = 'Опишите проблему или предложение. Можно прикрепить скриншот'
export function unavailableSupport(contact: SupportContact): string { return contact.state === 'self' ? 'Вы назначены поддержкой этого сервера. Отвечайте пользователям в обычных личных диалогах.' : contact.state === 'not_configured' ? 'Поддержка этого сервера пока не назначена.' : 'Поддержка этого сервера сейчас недоступна. Повторите позже.' }
