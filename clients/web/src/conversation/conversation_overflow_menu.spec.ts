import { createPinia } from 'pinia'
import { createSSRApp, nextTick } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { afterEach, describe, expect, it, vi } from 'vitest'

import DirectMessageConversation from '../direct_message/DirectMessageConversation.vue'
import TextConversation from './TextConversation.vue'
import { useConversationOverflowMenu } from './conversation_overflow_menu'

afterEach(() => vi.unstubAllGlobals())

describe('conversation overflow menu', () => {
  it('focuses menu actions, cycles arrows, restores focus on Escape, and closes on click-away', async () => {
    const search = vi.fn()
    const members = vi.fn()
    const state = useConversationOverflowMenu(search, members)
    let focused = ''
    const items = [{ focus: () => { focused = 'search' } }, { focus: () => { focused = 'members' } }]
    state.menu.value = { querySelector: () => items[0], querySelectorAll: () => items } as unknown as HTMLElement
    state.trigger.value = { focus: () => { focused = 'trigger' } } as HTMLButtonElement
    state.root.value = { contains: (target: unknown) => target === items[0] || target === items[1] } as HTMLElement
    vi.stubGlobal('document', { activeElement: items[0] })
    state.toggle()
    await nextTick()
    expect(state.expanded.value).toBe(true)
    expect(focused).toBe('search')
    state.onKeys({ key: 'ArrowDown', preventDefault: vi.fn() } as unknown as KeyboardEvent)
    expect(focused).toBe('members')
    state.onKeys({ key: 'Escape', stopPropagation: vi.fn(), preventDefault: vi.fn() } as unknown as KeyboardEvent)
    await nextTick()
    expect(state.expanded.value).toBe(false)
    expect(focused).toBe('trigger')
    state.toggle()
    state.onOutside({ target: {} } as PointerEvent)
    expect(state.expanded.value).toBe(false)
  })

  it.each(['ArrowDown','ArrowUp'])('opens the closed menu from the keyboard: %s', async key => {
    const state = useConversationOverflowMenu(vi.fn(), vi.fn())
    const first = {focus:vi.fn()}, last = {focus:vi.fn()}
    state.menu.value = {querySelectorAll:()=>[first,last]} as unknown as HTMLElement
    const preventDefault=vi.fn()
    state.onKeys({key,preventDefault} as unknown as KeyboardEvent)
    await nextTick()
    expect(state.expanded.value).toBe(true)
    expect(preventDefault).toHaveBeenCalledOnce()
    expect((key==='ArrowDown'?first:last).focus).toHaveBeenCalledOnce()
  })

  it('routes search and member actions without adding another command', async () => {
    const search = vi.fn()
    const members = vi.fn()
    const state = useConversationOverflowMenu(search, members)
    state.expanded.value = true
    state.openSearch()
    expect(search).toHaveBeenCalledOnce()
    expect(state.expanded.value).toBe(false)
    state.expanded.value = true
    state.toggleMembers()
    await nextTick()
    expect(members).toHaveBeenCalledOnce()
    expect(state.expanded.value).toBe(false)
  })

  it('wires one labelled disclosure into both conversation headers', async () => {
    const text = createSSRApp(TextConversation, { channelId: 'text-a', channelName: 'Общий', navOpen: false, membersOpen: false, showMembers: true })
    text.use(createPinia())
    const textHtml = await renderToString(text)
    expect(textHtml).toContain('aria-label="Другие действия"')
    expect(textHtml).toContain('aria-haspopup="menu" aria-expanded="false"')
    expect(textHtml).toContain('Показать участников')
    expect(textHtml).toContain('Файлы беседы')
    const controls = textHtml.match(/aria-label="Другие действия"[^>]*aria-controls="([^"]+)"/)
    expect(controls).not.toBeNull()
    expect(textHtml).toContain(`id="${controls?.[1]}"`)
    const dm = createSSRApp(DirectMessageConversation, { directMessageId: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Лера', navOpen: false })
    dm.use(createPinia())
    const dmHtml = await renderToString(dm)
    expect(dmHtml).toContain('aria-label="Другие действия"')
    expect(dmHtml).toContain('Найти сообщение')
    expect(dmHtml).toContain('Файлы беседы')
    expect(dmHtml).not.toContain('Показать участников')
    expect(dmHtml).not.toContain('Скрыть участников')
  })
})
