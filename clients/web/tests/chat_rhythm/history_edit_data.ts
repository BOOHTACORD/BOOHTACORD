export const uid = (n: number) => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`
export const own = uid(1), peer = uid(2), channelA = uid(3), channelB = uid(4)
export function wire(index: number, channel = channelA, revision = 1) {
  return { id: uid(1000 + index), channel_id: channel, author_id: own,
    client_message_id: uid(3000 + index), body: `History fixture ${index}`,
    revision, deleted: false, attachments: [], mention_user_ids: [peer],
    created_at: new Date(Date.UTC(2026, 9, 31, 0, 0, index)).toISOString() }
}
export function historyPage(before: string | null, after: string | null, count: number, channel = channelA) {
  const index = (id: string) => Number(id.slice(-12)) - 1000
  const high = before ? index(before) - 1 : after ? Math.min(999, index(after) + 20) : 999
  const low = before ? Math.max(0, high - 49) : after ? index(after) + 1 : 1000 - count
  return { messages: Array.from({ length: Math.max(0, high - low + 1) }, (_, i) => wire(high - i, channel)),
    ...(before || !after ? low > 0 ? { next_cursor: uid(1000 + low) } : {} : high < 999 ? { next_cursor: uid(1000 + high) } : {}) }
}
