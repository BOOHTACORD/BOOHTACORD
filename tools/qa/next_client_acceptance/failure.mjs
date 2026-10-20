import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const stages = new Set(['browser-launch', 'origin-navigation', 'api-ready', 'login', 'fixture-setup', 'reload', 'uploads', 'unread', 'navigation', 'receipt'])
const modules = new Set(['scenario.mjs', 'fixture.mjs', 'native_browser.mjs', 'uploads.mjs', 'unread.mjs', 'navigation.mjs',
  'cache_acl.mjs', 'navigation_fixture.mjs', 'window_visibility.mjs', 'input_files.mjs', 'revocation_sql.mjs'])
const errorName = error => ['Error', 'TimeoutError', 'AssertionError'].includes(error?.name) ? error.name : 'Error'
const networkErrors = new Set(['ERR_CONNECTION_REFUSED', 'ERR_CONNECTION_CLOSED', 'ERR_CONNECTION_RESET', 'ERR_CONNECTION_TIMED_OUT',
  'ERR_TIMED_OUT', 'ERR_ABORTED', 'ERR_NETWORK_CHANGED', 'ERR_NAME_NOT_RESOLVED', 'ERR_CERT_AUTHORITY_INVALID', 'ERR_EMPTY_RESPONSE', 'ERR_SSL_PROTOCOL_ERROR'])
const signals = new Set(['SIGHUP', 'SIGINT', 'SIGQUIT', 'SIGILL', 'SIGTRAP', 'SIGABRT', 'SIGBUS', 'SIGFPE', 'SIGKILL', 'SIGSEGV', 'SIGPIPE', 'SIGTERM'])

export function failureKind(error) {
  const message = typeof error?.message === 'string' ? error.message.slice(0, 16000) : ''
  if (message.includes('interrupted by another navigation')) return 'navigation-interrupted'
  if (message.includes('Target page, context or browser has been closed')) return 'target-closed'
  if (message.includes('Page crashed')) return 'page-crashed'
  if (message.includes('Execution context was destroyed')) return 'execution-context-destroyed'
  if (message.includes('Cannot find context with specified id')) return 'protocol-context-missing'
  if (message.includes('Protocol error (')) return 'protocol-error'
  if (message.includes('strict mode violation:')) return 'strict-locator'
  if (message.includes('Navigating frame was detached')) return 'frame-detached'
  const code = message.match(/net::(ERR_[A-Z_]+)\b/)?.[1]
  if (networkErrors.has(code)) return code
  return errorName(error) === 'TimeoutError' ? 'timeout' : 'other'
}

export function browserState(child, browser, page) {
  if (!child || !browser || !page) return null
  return { browser_connected: browser.isConnected(), page_closed: page.isClosed(),
    exit_code: Number.isInteger(child.exitCode) && child.exitCode >= 0 && child.exitCode <= 255 ? child.exitCode : null,
    signal: child.signalCode == null ? null : signals.has(child.signalCode) ? child.signalCode : 'other' }
}

export function failureSummary(error) {
  const name = errorName(error)
  return `FAIL: next-client acceptance (${name}); bounded diagnostics only`
}

export function failureContext(error, stage, nativeProcess = null) {
  const frames = []
  const stack = typeof error?.stack === 'string' ? error.stack.slice(0, 16000) : ''
  for (const line of stack.split('\n').slice(1)) {
    const match = line.match(/\/tools\/qa\/next_client_acceptance\/([a-z_]+\.mjs):(\d{1,6}):(\d{1,6})\)?$/)
    if (!match || !modules.has(match[1])) continue
    const [, module, row, column] = match
    if (Number(row) > 0 && Number(column) > 0) frames.push({ module, line: Number(row), column: Number(column) })
    if (frames.length === 8) break
  }
  return { schema_version: 2, status: 'FAIL', stage: stages.has(stage) ? stage : 'browser-launch', failure_type: errorName(error),
    failure_kind: failureKind(error), native_process: nativeProcess, frames }
}

export async function captureFailure(page, directory, error, stage, nativeProcess = null) {
  if (resolve(directory) !== resolve('.out/next-client-acceptance')) throw Error('Owned fixture diagnostics required')
  const receipt = failureContext(error, stage, nativeProcess)
  const writeReceipt = () => writeFileSync(resolve(directory, 'browser-failure.json'), JSON.stringify(receipt, null, 2) + '\n')
  writeReceipt()
  if (!page) return
  try {
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
  } catch (captureError) {
    receipt.capture_failure_kind = failureKind(captureError)
    writeReceipt()
    throw captureError
  }
}
