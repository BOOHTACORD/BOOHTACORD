import test from 'node:test'
import assert from 'node:assert/strict'
import { chromium } from './request.mjs'
import { voiceWorkspaceSearch } from './header_actions.mjs'

test('voice search opens the mobile navigation before using the shared search', async () => {
  const browser = await chromium.launch({ headless: true })
  try {
    const page = await browser.newPage({ viewport: { width: 393, height: 900 } })
    page.setDefaultTimeout(1500)
    await page.setContent(`
      <button aria-label="Открыть навигацию" onclick="document.querySelector('.guild-header').style.display='block'">Open</button>
      <div class="sidebar"><div class="guild-header" style="display:none">
        <button class="guild-search-button" onclick="document.querySelector('#panel').hidden=false">Search</button>
      </div></div>
      <div class="voice-room"><header class="conversation-header"><h2>Voice</h2></header></div>
      <div id="panel" data-testid="search-aside-panel" hidden>
        <button aria-label="Закрыть поиск" onclick="document.querySelector('#panel').remove()">Close</button>
      </div>`)
    const report = {}
    await voiceWorkspaceSearch(page, {}, report)
    assert.equal(report.header_actions.VOICE.workspace_search_retained, true)
  } finally {
    await browser.close()
  }
})
