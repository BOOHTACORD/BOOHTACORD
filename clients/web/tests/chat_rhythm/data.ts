export const uid = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`
export const own = uid(801), peer = uid(802), channel = uid(500), dm = uid(501)
export const bodies = ['Начало разговора.', 'Продолжение от того же автора.',
  'Ещё одна строка\nи вторая строка.', 'Другой автор вступает в разговор.',
  'Вложения остаются в ленте.', 'Текст после вложений.', 'Ответ на начало.',
  'Исправленный текст.', 'Удалённый текст.', 'Добро пожаловать в гильдию.',
  'العربية עברית — RTL\nhttps://example.test/'+'long-path-'.repeat(25)+'\n```ts\nconst value = "'+'code'.repeat(40)+'"\n```\nEmoji 👩🏽‍💻 🧑‍🚀 ❤️', 'Новый день.']
export const messages = bodies.map((body,i) => ({ id: uid(i+1), authorId: [3,4,5].includes(i) ? peer : own, clientMessageId: uid(100+i), body,
  createdAt: i === 11 ? '2026-10-16T10:00:00.000Z' : `2026-10-15T10:${String(i).padStart(2,'0')}:00.000Z`, revision: 1, deleted: i === 8,
  ...(i === 6 ? { replyToId: uid(1) } : {}), ...(i === 7 ? { editedAt: '2026-10-15T10:07:30.000Z' } : {}), ...(i === 9 ? {kind:'SYSTEM_WELCOME' as const} : {}),
  attachments: i === 4 ? [{ id: uid(901), originalName: 'Изображение.png', sizeBytes: 256 }, {id:uid(902),originalName:'Длинное-имя-документа-'.repeat(6)+'.pdf',sizeBytes:2048}] : [], mentionUserIds: [] }))
export const wire = (message: typeof messages[number], kind: string) => ({ id:message.id,author_id:message.authorId,client_message_id:message.clientMessageId,body:message.deleted?'':message.body,created_at:message.createdAt,revision:message.revision,deleted:message.deleted,
  ...(kind === 'CHANNEL' ? {channel_id:channel} : {direct_message_id:dm}), ...(message.replyToId ? {reply_to_id:message.replyToId,reply_preview:{id:uid(1),author_id:own,body:bodies[0],deleted:false}}:{}), ...(message.editedAt ? {edited_at:message.editedAt}:{}), ...(message.kind?{kind:message.kind}:{}),
  attachments:message.attachments.map(a=>({id:a.id,original_name:a.originalName,byte_size:a.sizeBytes})),mention_user_ids:[] })
