import assert from 'node:assert/strict'
import { api, channel, expect, openNavigation, status } from './request.mjs'

export async function memberProfile(page, report, directory) {
  const trigger = page.locator('.members-guild-roster .member-card').filter({ hasText: 'qa_member' })
  await trigger.click()
  const profile = page.getByTestId('member-popover')
  await expect(profile.getByRole('heading', { name: 'qa_member', exact: true })).toBeVisible()
  await expect(profile.getByRole('button', { name: 'Отключить от голоса', exact: true })).toHaveCount(0)
  await page.screenshot({ path: directory + '/member-profile-text.png' })
  await page.keyboard.press('Escape')
  await expect(trigger).toBeFocused()
  await trigger.click()
  await profile.getByRole('button', { name: 'Написать сообщение', exact: true }).click()
  await expect(page.locator('.direct-message-conversation')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'qa_member', exact: true })).toBeVisible()
  await expect(profile).toHaveCount(0)
  await openNavigation(page)
  await page.getByRole('button', { name: 'Каналы', exact: true }).click()
  await channel(page, 'Text')
  report.member_profile = { actual_member_api: true, keyboard_close_focus_return: true, contextual_dm_open: true, non_voice_admin_kick_hidden: true }
  console.log('stage=member-profile-text-dm-accepted')
}

export async function voiceMemberProfile(admin, member, input, report) {
  const adminProfile = await api(admin, '/me'), memberProfile = await api(member, '/me')
  for (const [page, other, administrator] of [[admin, memberProfile.body, true], [member, adminProfile.body, false]]) {
    const rail = page.getByTestId('members-panel')
    if (!(await rail.isVisible())) await page.getByRole('button', { name: 'Открыть участников', exact: true }).click()
    const trigger = rail.locator('.members-voice-roster .member-card').filter({ hasText: other.display_name })
    await trigger.click()
    const profile = page.getByTestId('member-popover')
    await expect(profile.getByRole('heading', { name: other.display_name, exact: true })).toBeVisible()
    const slider = profile.getByRole('slider')
    await slider.focus(); await slider.press('ArrowRight')
    await expect(slider).toHaveValue('101')
    await expect(profile.locator('output')).toHaveText('101%')
    await expect(profile.getByRole('button', { name: 'Отключить от голоса', exact: true })).toHaveCount(Number(administrator))
    if (!administrator) status(await api(page, `/admin/accounts/${other.account_id}/voice-kick`, 'POST'), 403)
    await page.screenshot({ path: input.directory + `/member-profile-voice-${administrator ? 'admin' : 'member'}.png` })
    await page.keyboard.press('Escape'); await expect(trigger).toBeFocused()
    // Restore mixer state and close the existing modal drawer before subsequent media checks.
    await trigger.click(); await slider.focus(); await slider.press('ArrowLeft'); await expect(slider).toHaveValue('100')
    await page.keyboard.press('Escape')
    if (await page.locator('.drawer-scrim').isVisible()) await page.locator('.drawer-scrim').click({ position: { x: 4, y: 4 } })
    assert.equal(await page.evaluate(() => window.__qaPeers.some(p => p.connectionState === 'connected')), true)
  }
  Object.assign(report.member_profile, { actual_sfu_participant_volume: true, admin_action_scoped_to_voice: true, member_kick_api_denied: true, same_transport_retained: true })
  console.log('stage=member-profile-voice-acl-accepted')
}
