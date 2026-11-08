import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function template(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }
function field(source: string, model: string): string {
  return source.match(new RegExp(`<(?:input|textarea|select)[^>]*v-model="${model}"[^>]*>`))?.[0] ?? ''
}

describe('Unicode form boundary contract', () => {
  it.each([
    ['../../identity/AuthenticationLanding.vue', 'password'],
    ['../../identity/ProfileSettings.vue', 'displayName'],
    ['../../identity/ProfileSettings.vue', 'currentPassword'],
    ['../../identity/ProfileSettings.vue', 'newPassword'],
    ['../../channel/AdminCategoryControls.vue', 'newName'],
    ['../../channel/AdminChannelCreate.vue', 'channelName'],
    ['../../conversation/TextConversation.vue', 'draft'],
    ['../../direct_message/DirectMessageConversation.vue', 'draft'],
    ['../../conversation/MessageItem.vue', 'body'],
    ['../../search/SearchPanel.vue', 'query'],
  ])('lets the code-point validator handle %s / %s and exposes errors', (path, model) => {
    const source = template(path)
    const input = field(source, model)
    expect(input).not.toBe('')
    expect(input).not.toMatch(/\b(?:max|min)length=/)
    expect(input).toContain(':aria-describedby=')
    expect(source).toContain('role="alert"')
  })

  it('keeps the ASCII login constraint in the browser', () => {
    expect(field(template('../../identity/AuthenticationLanding.vue'), 'loginValue')).toContain('maxlength="32"')
  })

  it.each([
    ['../../channel/AdminCategoryControls.vue', 'rename-category'],
    ['../../channel/AdminChannelRename.vue', 'channel-new-name'],
  ])('does not truncate renamed %s before the code-point check', (path, name) => {
    const input = template(path).match(new RegExp(`<input[^>]*name="${name}"[^>]*>`))?.[0] ?? ''
    expect(input).not.toBe('')
    expect(input).not.toContain('maxlength=')
    expect(input).toContain(':aria-describedby=')
  })
})
