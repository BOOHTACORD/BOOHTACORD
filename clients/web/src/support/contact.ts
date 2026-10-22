export interface SupportContact { state: 'available' | 'not_configured' | 'unavailable' | 'self'; revision: number; accountId?: string }
export const noSupport: SupportContact = { state: 'not_configured', revision: 0 }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
export function parseSupportContact(value: unknown): SupportContact {
 if (!value || typeof value !== 'object' || Array.isArray(value)) return {...noSupport}
 const v = value as Record<string, unknown>
 if (!Number.isSafeInteger(v.revision) || (v.revision as number) < 0) return {state:'unavailable', revision:0}
 const revision = v.revision as number
 if (v.state === 'available' && revision > 0 && typeof v.account_id === 'string' && uuid.test(v.account_id)) return {state:'available', revision, accountId:v.account_id}
 if (v.state === 'self' || v.state === 'not_configured' || v.state === 'unavailable') return {state:v.state, revision}
 return {state:'unavailable', revision}
}
export function isSupportPeer(peer: string, contact: SupportContact): boolean { return contact.state === 'available' && contact.accountId === peer }
export function supportPresentation(item: {otherParticipantId: string; otherParticipantDisplayName: string}, contact: SupportContact): string {
 return isSupportPeer(item.otherParticipantId, contact) ? 'Поддержка' : item.otherParticipantDisplayName
}
export const supportPrivacy = 'Сообщения видит назначенная поддержка этого сервера. Для исправления ошибок команда может создать публичную техническую задачу без вашего текста и файлов.'
export const supportPrompt = 'Опишите проблему или предложение. Можно прикрепить скриншот'
export function unavailableSupport(contact: SupportContact): string { return contact.state === 'self' ? 'Вы назначены поддержкой этого сервера. Отвечайте пользователям в обычных личных диалогах.' : contact.state === 'not_configured' ? 'Поддержка этого сервера пока не назначена.' : 'Поддержка этого сервера сейчас недоступна. Повторите позже.' }
