import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const stages = new Set(['browser-launch', 'api-ready', 'login', 'fixture-setup', 'reload', 'uploads', 'unread', 'navigation', 'receipt'])
const modules = new Set(['scenario.mjs', 'fixture.mjs', 'native_browser.mjs', 'uploads.mjs', 'unread.mjs', 'navigation.mjs',
  'cache_acl.mjs', 'navigation_fixture.mjs', 'window_visibility.mjs', 'input_files.mjs', 'revocation_sql.mjs'])
const errorName = error => ['Error', 'TimeoutError', 'AssertionError'].includes(error?.name) ? error.name : 'Error'

export function failureSummary(error) {
  const name = errorName(error)
  return `FAIL: next-client acceptance (${name}); bounded diagnostics only`
}

export function failureContext(error, stage) {
  const frames = []
  const stack = typeof error?.stack === 'string' ? error.stack.slice(0, 16000) : ''
  for (const line of stack.split('\n').slice(1)) {
    const match = line.match(/\/tools\/qa\/next_client_acceptance\/([a-z_]+\.mjs):(\d{1,6}):(\d{1,6})\)?$/)
    if (!match || !modules.has(match[1])) continue
    const [, module, row, column] = match
    if (Number(row) > 0 && Number(column) > 0) frames.push({ module, line: Number(row), column: Number(column) })
    if (frames.length === 8) break
  }
  return { schema_version: 1, status: 'FAIL', stage: stages.has(stage) ? stage : 'browser-launch', failure_type: errorName(error), frames }
}

export async function captureFailure(page, directory, error, stage) {
  if (resolve(directory) !== resolve('.out/next-client-acceptance')) throw Error('Owned fixture diagnostics required')
  writeFileSync(resolve(directory, 'browser-failure.json'), JSON.stringify(failureContext(error, stage), null, 2) + '\n')
  if (!page) return
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
