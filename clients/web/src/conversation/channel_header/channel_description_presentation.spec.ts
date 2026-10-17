import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const conversation = readFileSync(new URL('../TextConversation.vue', import.meta.url), 'utf8')
const pane = readFileSync(new URL('../ConversationPane.vue', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../../design/design_v2_chat_presentation.css', import.meta.url), 'utf8')

describe('server-authored text channel description', () => {
  it('passes only the selected channel description to the chat heading', () => {
    expect(pane).toContain(':channel-description="channel.description"')
    expect(conversation).toContain('<small v-if="channelDescription" :title="channelDescription">{{ channelDescription }}</small>')
  })

  it('keeps the compact mobile chat heading to one line', () => {
    expect(presentation).toMatch(/@media \(max-width: 720px\)\s*\{\s*\.text-conversation \.main-title small\s*\{ display: none; \}/)
  })
})
