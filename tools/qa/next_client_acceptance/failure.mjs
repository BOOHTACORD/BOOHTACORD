import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

export function failureLocation(error) {
  if (typeof error?.stack !== 'string') return 'unknown'
  // Keep only reviewed source names and line numbers; never copy stack text.
  const frame = error.stack.slice(0, 8192).match(/^\s+at [^\r\n]*\/tools\/qa\/next_client_acceptance\/(fixture|uploads|unread|navigation|cache_acl|scenario|native_browser|window_visibility|input_files|visibility_smoke|navigation_fixture)\.mjs:([1-9][0-9]{0,3}):[0-9]{1,4}\)?$/m)
  return frame ? `${frame[1]}.mjs:${frame[2]}` : 'unknown'
}

export function failureSummary(error) {
  const name = ['Error', 'TimeoutError', 'AssertionError'].includes(error?.name) ? error.name : 'Error'
  const location = failureLocation(error)
  return `FAIL: next-client acceptance (${name}); bounded diagnostics only` + (location === 'unknown' ? '' : `; source=${location}`)
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
