import { defineStore } from 'pinia'
import { computed, onScopeDispose, ref } from 'vue'

import { loadMember, loadMembers, type GuildMember, type ProfileRequest } from './profile_client'

function keepLatest(incoming: GuildMember[], current: GuildMember[]): GuildMember[] {
  const previous = new Map(current.map((member) => [member.user_id, member]))
  return incoming.map((member) => {
    const latest = previous.get(member.user_id)
    return latest && (latest.profile_revision ?? 0) > (member.profile_revision ?? 0)
      ? { ...member, display_name: latest.display_name, avatar_url: latest.avatar_url, profile_revision: latest.profile_revision }
      : member
  })
}

export const useMemberDirectory = defineStore('member-directory', () => {
  const members = ref<GuildMember[]>([])
  const cursor = ref<string | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  let running: Promise<void> | null = null
  const lookups = new Map<string, Promise<void>>()
  let overflow: Promise<void> | null = null
  let active = true
  onScopeDispose(() => { active = false; lookups.clear() })

  const byId = computed(() => Object.fromEntries(members.value.map((member) => [member.user_id, member])))

  function load(cursorValue?: string, request?: ProfileRequest): Promise<void> {
    if (running) return running
    loading.value = true
    error.value = null
    const current = members.value
    const task = loadMembers(cursorValue, request).then((page) => {
      if (!active) return
      const previousIDs = new Set(current.map(member => member.user_id))
      const addedDuringLoad = members.value.filter(member => !previousIDs.has(member.user_id))
      const incoming = [...new Map((cursorValue ? [...members.value, ...page.members] : [...page.members, ...addedDuringLoad]).map(member => [member.user_id, member])).values()]
      members.value = keepLatest(incoming, members.value)
      cursor.value = page.next_cursor ?? null
    }).catch((cause: unknown) => {
      error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить участников.'
    }).finally(() => {
      loading.value = false
      if (running === tracked) running = null
    })
    const tracked = task
    running = tracked
    return tracked
  }

  function refresh(request?: ProfileRequest): Promise<void> { return load(undefined, request) }
  async function invalidate(request?: ProfileRequest): Promise<void> {
    const loadedCount = members.value.length
    if (running) await running
    await refresh(request)
    while (cursor.value && members.value.length < loadedCount) {
      const previousCursor = cursor.value
      await loadNext(request)
      if (error.value || cursor.value === previousCursor) break
    }
  }
  function loadNext(request?: ProfileRequest): Promise<void> {
    return cursor.value ? load(cursor.value, request) : Promise.resolve()
  }

  function ensureMember(userId: string, request?: ProfileRequest): Promise<void> {
    if (!active || !userId || byId.value[userId]) return Promise.resolve()
    const pending = lookups.get(userId)
    if (pending) return pending
    if (lookups.size >= 32) {
      if (!overflow) overflow = invalidate(request).finally(() => { overflow = null })
      return overflow
    }
    const task = loadMember(userId, request).then(member => {
      if (active && member.user_id === userId && !byId.value[userId]) members.value = [...members.value, member]
    }).catch(() => { /* The member can be unavailable or no longer visible. */ }).finally(() => { lookups.delete(userId) })
    lookups.set(userId, task)
    return task
  }

  return { byId, cursor, error, ensureMember, invalidate, load, loadNext, loading, members, refresh }
})
