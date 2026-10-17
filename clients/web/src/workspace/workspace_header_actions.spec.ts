import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import WorkspaceHeaderActions from '../shared/workspace_header/WorkspaceHeaderActions.vue'
import { memberHeaderExpanded } from './member_header_expanded'

describe('conversation header actions', () => {
  it('reports the real member-panel state at desktop, narrow, and wide voice layouts', () => {
    expect(memberHeaderExpanded(true, false, false)).toBe(true)
    expect(memberHeaderExpanded(true, false, true)).toBe(false)
    expect(memberHeaderExpanded(false, false, false)).toBe(false)
    expect(memberHeaderExpanded(false, false, true)).toBe(true)
    expect(memberHeaderExpanded(true, true, false)).toBe(false)
    expect(memberHeaderExpanded(true, true, true)).toBe(true)
  })

  it('gives the TEXT member toggle an accurate label and keeps it absent in DM', async () => {
    const expanded = await renderToString(createSSRApp(WorkspaceHeaderActions, { navExpanded: false, membersExpanded: true, showMembers: true }))
    expect(expanded).toContain('aria-label="Скрыть участников"')
    expect(expanded).toContain('aria-controls="members-panel" aria-expanded="true"')
    const collapsed = await renderToString(createSSRApp(WorkspaceHeaderActions, { navExpanded: false, membersExpanded: false, showMembers: true }))
    expect(collapsed).toContain('aria-label="Открыть участников"')
    expect(collapsed).toContain('aria-controls="members-panel" aria-expanded="false"')
    const dm = await renderToString(createSSRApp(WorkspaceHeaderActions, { navExpanded: false, membersExpanded: false, showMembers: false }))
    expect(dm).not.toContain('members-panel')
  })

  it('names expanded navigation as close rather than open', async () => {
    const html = await renderToString(createSSRApp(WorkspaceHeaderActions, { navExpanded:true, membersExpanded:false, showMembers:false }))
    expect(html).toContain('aria-label="Закрыть навигацию"')
  })
})
