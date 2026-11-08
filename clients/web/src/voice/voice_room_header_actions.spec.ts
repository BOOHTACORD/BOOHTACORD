import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('voice room header actions', () => {
  it('keeps message search in the workspace launcher rather than the conversation header', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const main = source('../workspace/WorkspaceMain.vue')
    const app = source('../workspace/WorkspaceApp.vue')
    expect(pane).not.toContain('Найти сообщение')
    expect(main).not.toContain('openSearch')
    expect(app).toContain('<SearchLauncher')
    expect(pane).toContain('<ConversationOverflowMenu')
    expect(app).toContain('@open="requestPanel(\'search\')"')
  })

  it('labels the voice menu and uses a participant icon for the member toggle', () => {
    expect(source('../conversation/ConversationPane.vue')).toContain('menu-label="Действия голосового канала"')
    expect(source('../conversation/ConversationOverflowMenu.vue')).toContain(':aria-label="props.menuLabel"')
    expect(source('../shared/workspace_header/WorkspaceHeaderActions.vue')).toContain('M17 20v-2a4 4 0 0 0-4-4')
  })
})
