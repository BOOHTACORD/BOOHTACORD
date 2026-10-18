import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

export function failureSummary(error) {
  const name = ['Error', 'TimeoutError', 'AssertionError'].includes(error?.name) ? error.name : 'Error'
  return `FAIL: next-client acceptance (${name}); bounded diagnostics only`
}

export async function captureFailure(page, directory) {
  if (resolve(directory) !== resolve('.out/next-client-acceptance')) throw Error('Owned fixture diagnostics required')
  const state = await page.evaluate(() => {
    const main = document.querySelector('.message-history-wrap .message-list')
    const context = document.querySelector('[data-testid="search-message-context"]')
    const visible = element => Boolean(element?.getClientRects().length)
    const count = (element, selector) => element?.querySelectorAll(selector).length ?? 0
    const viewport = main ? Object.fromEntries(['scrollTop', 'scrollHeight', 'clientHeight'].map(key => [key, Math.round(main[key])])) : null
    return { main_history_visible: visible(main), context_visible: visible(context),
      saved_position_context: context?.querySelector('h2,h3')?.textContent?.trim() === 'Сохранённая позиция',
      main_rendered_rows: count(main, '[data-message-id]'), main_reply_previews: count(main, '.reply-preview'),
      context_rows: count(context, '[data-message-id]'), viewport }
  })
  writeFileSync(resolve(directory, 'failure.json'), JSON.stringify(state, null, 2) + '\n')
  await page.screenshot({ path: resolve(directory, 'failure.png') })
}
