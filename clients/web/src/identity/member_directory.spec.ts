import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useMemberDirectory } from './member_directory'

const page = (name: string, revision: number) => new Response(JSON.stringify({
  members: [{ user_id: 'user-2', login: 'member', display_name: name, role: 'MEMBER', presence: 'online', avatar_url: '/api/v1/members/user-2/avatar', profile_revision: revision }],
}))

describe('member directory', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('coalesces refreshes and keeps newer metadata when a stale page arrives', async () => {
    const directory = useMemberDirectory()
    const initial = vi.fn().mockResolvedValue(page('Актуальное имя', 6))
    await directory.refresh(initial)
    expect(directory.byId['user-2'].display_name).toBe('Актуальное имя')

    let resolve: ((response: Response) => void) | undefined
    const stale = vi.fn(() => new Promise<Response>((done) => { resolve = done }))
    const first = directory.refresh(stale)
    const second = directory.refresh(stale)
    expect(stale).toHaveBeenCalledTimes(1)
    resolve?.(page('Старое имя', 5))
    await Promise.all([first, second])
    expect(directory.byId['user-2'].display_name).toBe('Актуальное имя')
    expect(directory.byId['user-2'].profile_revision).toBe(6)
  })

  it('schedules one fresh roster after invalidation races an in-flight page', async () => {
    const directory = useMemberDirectory()
    const replies: Array<(response: Response) => void> = []
    const request = vi.fn(() => new Promise<Response>((resolve) => replies.push(resolve)))
    const initial = directory.refresh(request)
    const invalidated = directory.invalidate(request)
    expect(request).toHaveBeenCalledTimes(1)
    replies[0](page('Старое имя', 2))
    await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(2))
    replies[1](page('Новое имя', 3))
    await Promise.all([initial, invalidated])
    expect(directory.byId['user-2'].display_name).toBe('Новое имя')
  })

  it('loads an arriving member once and does not duplicate a later page', async () => {
    const directory = useMemberDirectory()
    let complete!: (response: Response) => void
    const request = vi.fn(() => new Promise<Response>(resolve => { complete = resolve }))
    const first = directory.ensureMember('user-2', request)
    const second = directory.ensureMember('user-2', request)
    expect(request).toHaveBeenCalledTimes(1)
    complete(new Response(JSON.stringify({ user_id: 'user-2', login: 'member', display_name: 'Новый', role: 'MEMBER', presence: 'online', profile_revision: 1 })))
    await Promise.all([first, second])
    expect(directory.byId['user-2'].display_name).toBe('Новый')
    await directory.load(undefined, vi.fn().mockResolvedValue(page('Новый', 1)))
    expect(directory.members).toHaveLength(1)
  })

  it('keeps a new arrival when an older directory page finishes later', async () => {
    const directory = useMemberDirectory()
    let finish!: (response: Response) => void
    const stale = directory.refresh(vi.fn(() => new Promise<Response>(resolve => { finish = resolve })))
    await directory.ensureMember('user-2', vi.fn().mockResolvedValue(new Response(JSON.stringify({ user_id: 'user-2', login: 'member', display_name: 'New', role: 'MEMBER', presence: 'online' }))))
    finish(new Response(JSON.stringify({ members: [] })))
    await stale
    expect(directory.members.map(member => member.user_id)).toEqual(['user-2'])
  })
})
