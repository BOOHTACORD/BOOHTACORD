import { randomUUID } from 'node:crypto'
import { api, channel, expect, status } from '../request.mjs'

export async function memberLog(a, value, input, report) {
  const logMessages = [
    'Synthetic UIUX log sample: first readable entry.',
    'Synthetic UIUX log sample: labels, timestamps and actions.',
    'Synthetic UIUX log sample: wrapping at narrow viewports.',
  ]
  for (const body of logMessages) {
    status(await api(a, `/channels/${value.logChannelId}/messages`, 'POST', {
      client_message_id: randomUUID(), body,
    }), 201)
  }
  await channel(a, 'log')
  const logHistory = a.getByRole('log', { name: 'История сообщений' })
  await expect(logHistory).toContainText(logMessages[2])
  const firstLogMessage = a.locator('.message-row').filter({ hasText: logMessages[0] }).first()
  await expect(firstLogMessage).toBeVisible()
  if (input.viewport.has_touch) {
    await firstLogMessage.locator('.message-actions-toggle').tap()
    await expect(firstLogMessage.locator('.message-actions')).toHaveClass(/is-open/)
  } else {
    await firstLogMessage.hover()
  }
  await expect(firstLogMessage.getByRole('button', { name: 'Удалить', exact: true })).toBeVisible()
  await expect.poll(() => a.locator('#message-body').evaluate(element =>
    element.closest('form').getBoundingClientRect().bottom <= window.innerHeight + 0.5
  ), { message: 'log composer must fit after opening message actions' }).toBe(true)
  await a.screenshot({ path: input.directory+'/channel-log.png' })
  report.catalog_channel_log = { synthetic_messages_visible: true, source_channel: 'log', admin_delete_action_reachable: true }
  console.log('stage=qa-member-channel-log-complete')
}
