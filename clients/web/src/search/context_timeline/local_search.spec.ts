import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest'

it('keeps only the workspace message search and removes per-conversation search panels', () => {
  const text = readFileSync(new URL('../../conversation/TextConversation.vue', import.meta.url), 'utf8')
  const directMessage = readFileSync(new URL('../../direct_message/DirectMessageConversation.vue', import.meta.url), 'utf8')
  const workspace = readFileSync(new URL('../../workspace/WorkspaceApp.vue', import.meta.url), 'utf8')
  expect(text).not.toContain('TextMessageSearch')
  expect(text).not.toContain('Найти сообщение')
  expect(text).not.toContain('conversation-tools')
  expect(directMessage).not.toContain('DirectMessageSearch')
  expect(directMessage).not.toContain('Найти сообщение')
  expect(directMessage).not.toContain('conversation-tools')
  expect(workspace).toContain('<SearchLauncher')
})
