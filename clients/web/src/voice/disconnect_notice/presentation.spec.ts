import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { expect, it } from 'vitest'
import VoicePrejoin from '../VoicePrejoin.vue'
import { disconnectNotice } from './model'
it.each(['KICK', 'CHANNEL_CLOSED', 'BANNED', 'TRANSFER', 'TRANSPORT'] as const)('renders reason and action policy for %s', async reason => {
  const notice = disconnectNotice(reason, reason === 'TRANSPORT' ? 'transport' : 'server')
  const html = await renderToString(createSSRApp({ render: () => h(VoicePrejoin, { channelId: 'channel', voiceError: 'technical error', voiceState: 'ERROR', voiceTransferRequired: false, notice }) }))
  expect(html).toContain(notice.message); expect(html).toContain(notice.explanation)
  expect(html).toContain('role="status"'); expect(html).toContain('aria-atomic="true"')
  expect(html).not.toContain('technical error')
  expect(html).toContain('Войти'); expect(html).toContain('Без микрофона')
  expect((html.match(/disabled/g) ?? []).length).toBe(notice.reconnectAllowed ? 0 : 2)
})
