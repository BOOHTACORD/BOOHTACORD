import { expect, test } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { routes } from './routes'
import { id } from '../control_consistency/routes'

const scenes = ['prejoin', 'dock', 'search', 'chat', 'dm', 'audio', 'profile', 'share', 'quick', 'archive', 'files', 'mentions',
  ...['guild', 'members', 'roles', 'channels', 'audit', 'media', 'readiness'].map(section => `admin&section=${section}`),
  ...['Безопасность', 'Уведомления', 'О приложении'].map(tab => `profile&tab=${tab}`)]

for (const width of [1440, 390]) for (const scene of scenes) test(`copy inventory ${scene} at ${width}px`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  await routes(page)
  await page.goto(`/tests/microcopy/fixture.html?surface=${scene}`)
  const tab = new URLSearchParams(`surface=${scene}`).get('tab')
  if (tab) await page.getByRole('tab', { name: tab, exact: true }).click()
  if (scene.startsWith('admin&section=guild')) await expect(page.getByLabel('Название гильдии', { exact: true })).toBeEnabled()
  if (scene === 'search') await expect(page.getByRole('button', { name: 'Найти', exact: true })).toBeVisible()
  if (scene === 'chat') await expect(page.locator('#message-body')).toBeVisible()
  if (scene === 'dm') await expect(page.locator('#direct-message-body')).toBeVisible()
  if (scene === 'archive') await page.getByLabel('Канал', { exact: true }).selectOption(id)
  if (scene === 'mentions') await expect(page.getByText('Пока нет упоминаний.', { exact: true })).toBeVisible()
  if (tab === 'Безопасность') await expect(page.locator('.own-sessions')).toHaveAttribute('aria-busy', 'false')
  if (scene === 'admin&section=roles') await expect(page.locator('.role-permissions').getByRole('alert')).toHaveCount(0)
  await page.evaluate(() => document.fonts.ready)
  const inventory = await page.locator('p, small, summary').evaluateAll(elements => elements.filter(e => !e.closest('.messages, .message-item, .search-results')).map(e => {
    const r = e.getBoundingClientRect(), s = getComputedStyle(e)
    const clipped = s.clip !== 'auto' || ['gc-sr-only', 'visually-hidden'].some(c => e.classList.contains(c) || e.closest(`.${c}`))
    const segments: string[] = []
    for (let node: Element | null = e; node && node.tagName !== 'MAIN'; node = node.parentElement) {
      if (node.id) { segments.unshift(`#${CSS.escape(node.id)}`); break }
      const siblings = [...(node.parentElement?.children ?? [])].filter(sibling => sibling.tagName === node!.tagName)
      segments.unshift(node.tagName.toLowerCase() + [...node.classList].map(c => `.${CSS.escape(c)}`).join('') + (siblings.length > 1 ? `:nth-of-type(${siblings.indexOf(node) + 1})` : ''))
    }
    const selector = segments.join(' > ')
    return { selector, text: e.textContent?.trim().replace(/\s+/g, ' '), visible: e.checkVisibility() && r.width > 1 && r.height > 1 && !clipped }
  }))
  await writeFile(info.outputPath('copy-inventory.json'), JSON.stringify({ scene, width, inventory }, null, 2))
  await page.screenshot({ path: info.outputPath('screen.png'), fullPage: true })
})
