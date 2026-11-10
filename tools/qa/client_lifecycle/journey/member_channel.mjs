import { channel, expect, login } from '../request.mjs'
import { conversationHeaders } from '../header_actions.mjs'
import { searchTabs } from '../search_tabs.mjs'
import { searchPresentation } from '../search_presentation.mjs'

export async function memberChannel(guest, b, value, input, report) {
  await login(guest, 'qa_member', input.password, input.directory)
  console.log(`stage=qa-member-login:${input.viewport.width}`)
  await channel(guest, 'Text', value.channelId)
  await expect(guest.getByRole('heading', { name: 'Text', exact: true })).toBeVisible()
  console.log('stage=qa-member-text-channel-selected')
  const channelHistory = guest.getByRole('log', { name: 'История сообщений' })
  await expect(channelHistory).toContainText('Synthetic UIUX channel sample: wrapping at narrow viewports.')
  console.log('stage=qa-member-message-history-visible')
  await conversationHeaders(guest, input, report, 'TEXT')
  await guest.screenshot({ path: input.directory+'/channel-text.png' })
  const firstChannelMessage = guest.locator('.message-row')
    .filter({ hasText: 'Synthetic UIUX channel sample: wrapping at narrow viewports.' }).first()
  await expect(firstChannelMessage).toBeVisible()
  console.log('stage=qa-member-first-message-visible')
  const messageActionsToggle = firstChannelMessage.locator('.message-actions-toggle')
  const messageActionButtons = firstChannelMessage.locator('.message-action-buttons')
  if (input.viewport.has_touch) {
    await messageActionsToggle.tap()
    await expect(firstChannelMessage.locator('.message-actions')).toHaveClass(/is-open/)
    console.log('stage=qa-member-message-actions-open-touch')
  } else {
    await firstChannelMessage.hover()
    await expect(firstChannelMessage.getByRole('button', { name: 'Ответить' })).toBeVisible()
    await expect(messageActionButtons).toHaveCSS('opacity', '1')
    console.log('stage=qa-member-message-actions-open-mouse')
  }
  await guest.screenshot({ path: input.directory+'/channel-text-actions.png' })
  if (input.viewport.has_touch) {
    await messageActionsToggle.tap()
    await expect(firstChannelMessage.locator('.message-actions')).not.toHaveClass(/is-open/)
  } else {
    await guest.mouse.move(0, 0)
    await expect(messageActionButtons).toHaveCSS('opacity', '0')
    await expect(messageActionButtons).toHaveCSS('pointer-events', 'none')
  }
  report.catalog_message_actions = { open: true, close: true, pointer: input.viewport.has_touch ? 'touch' : 'mouse' }
  console.log('stage=qa-member-message-actions-complete')
  await searchTabs(guest, input, report)
  await searchPresentation(guest, b, value, input, report)

  await channel(guest, 'Voice')
  await expect(guest.getByRole('heading', { name: 'Войти в голос', exact: true })).toBeVisible()
  await expect(guest.getByRole('button', { name: 'Войти', exact: true })).toBeVisible()
  await expect(guest.getByRole('button', { name: 'Без микрофона', exact: true })).toBeVisible()
  await guest.screenshot({ path: input.directory+'/voice-prejoin.png' })
  report.catalog_voice_prejoin = { channel_selected: true, connection_not_started: true, join_modes_visible: true }
  console.log('stage=qa-member-voice-prejoin-complete')
}
