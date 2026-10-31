import { ref } from 'vue'

export interface StoredDraft<Reply, Attachment> {
  body: string
  replyTarget: Reply | null
  attachments: Attachment[]
  mentionUserIds: string[]
}

const memory = new Map<string, { revision: number; signature: string; draft: StoredDraft<unknown, unknown> }>()
const epoch = ref(0)
let revision = 0

export function draftKey(accountId: string, kind: 'CHANNEL' | 'DIRECT_MESSAGE', conversationId: string): string {
  return JSON.stringify([accountId, kind, conversationId])
}

export function saveDraft<Reply, Attachment>(key: string, value: StoredDraft<Reply, Attachment>): void {
  if (!value.body && !value.replyTarget && !value.attachments.length && !value.mentionUserIds.length) {
    memory.delete(key)
    return
  }
  const draft = { ...value, attachments: [...value.attachments], mentionUserIds: [...value.mentionUserIds] }
  const signature = JSON.stringify([value.body, (value.replyTarget as { id?: string } | null)?.id,
    value.attachments.map((attachment) => (attachment as { id?: string }).id), value.mentionUserIds])
  if (memory.get(key)?.signature === signature) return
  memory.set(key, { revision: ++revision, signature, draft })
}

export function loadDraft<Reply, Attachment>(key: string): StoredDraft<Reply, Attachment> | null {
  const value = memory.get(key)?.draft
  return value ? { body: value.body, replyTarget: value.replyTarget as Reply | null,
    attachments: [...value.attachments] as Attachment[], mentionUserIds: [...value.mentionUserIds] } : null
}

export function draftMemoryEpoch(): number { return epoch.value }
export function draftRevision(key: string): number { return memory.get(key)?.revision ?? 0 }
export function clearDraftIfRevision(key: string, expectedRevision: number): boolean {
  if (!expectedRevision || draftRevision(key) !== expectedRevision) return false
  memory.delete(key)
  return true
}
export function clearDraftMemory(): void { memory.clear(); epoch.value++ }
