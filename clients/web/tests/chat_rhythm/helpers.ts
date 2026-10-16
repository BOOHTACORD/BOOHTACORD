import { expect, type Page } from '@playwright/test'
import { routes } from './routes'
import { uid } from './data'
export const kinds = ['CHANNEL', 'DIRECT_MESSAGE'] as const
export const row = (page: Page, n: number) => page.locator(`[data-message-id="${uid(n)}"]`)
export async function mount(page: Page, kind: string, older = false) {
  const state = await routes(page, kind, false, older)
  await page.goto(`/tests/chat_rhythm/fixture.html?kind=${kind}`)
  await expect(page.locator('[data-message-id]')).not.toHaveCount(0)
  await page.evaluate(() => document.fonts.ready)
  await page.locator('.message-list').evaluate(el => { el.scrollTop = 0; el.dispatchEvent(new Event('scroll')) })
  await expect(row(page, 1)).toBeVisible()
  await expect(page.getByText('Загрузка реакций…', { exact: true })).toHaveCount(0)
  // Scroll/ResizeObserver and font metrics can settle before Chromium has painted
  // every virtual row. Capture after two paint opportunities, never a partial frame.
  await page.evaluate(async () => {
    await Promise.all([...document.images].map(image => image.decode().catch(() => {})))
    await new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve())))
  })
  return state
}
export async function metrics(page: Page) {
  return page.evaluate(() => {
    const list = document.querySelector<HTMLElement>('.message-list')!
    return { viewport: { width: innerWidth, height: innerHeight }, scrollHeight: list.scrollHeight,
      composerHeight: document.querySelector('.composer')!.getBoundingClientRect().height,
      rows: [...list.querySelectorAll<HTMLElement>('[data-message-id]')].map(el => {
        const r = el.getBoundingClientRect(), meta = el.querySelector('.message-meta')?.getBoundingClientRect()
        return { id: el.dataset.messageId, grouped: el.classList.contains('grouped-message'), height: r.height,
          gap: parseFloat(getComputedStyle(el).paddingTop) || parseFloat(getComputedStyle(el).marginTop) || 0,
          metaHeight: meta?.height ?? 0,
          timestamps: [...el.querySelectorAll('time')].map(t => ({ text: t.textContent, datetime: t.getAttribute('datetime'),
            label: t.getAttribute('aria-label'), title: t.title, painted: t.getBoundingClientRect().height > 0 && !t.closest('.gc-sr-only') })),
        }
      }),
    }
  })
}
export async function expectWithinViewport(page: Page) {
  const overflow = await page.evaluate(() => [...document.querySelectorAll<HTMLElement>(
    '.message-content,.message-meta,.message-body,.message-code,.attachment-card,.composer,.history-date,.system-welcome-message',
  )].filter(el => el.getClientRects().length).flatMap(el => {
    const rect = el.getBoundingClientRect()
    return rect.left < -1 || rect.right > innerWidth + 1 ? [{ class: el.className, left: rect.left, right: rect.right, width: innerWidth }] : []
  }))
  expect(overflow).toEqual([])
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
}
