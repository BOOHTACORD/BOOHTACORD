import assert from 'node:assert/strict'
import { expect } from './request.mjs'

// No test-only routes: use the mounted conversation and the owned Go API/SFU.
export async function conversationHeaders(page, input, report, kind) {
  const conversation = page.locator(kind === 'TEXT' ? '.text-conversation' : '.direct-message-conversation')
  const header = conversation.locator(':scope > .conversation-header')
  const title = await header.locator('h2').textContent()
  const composer = conversation.getByRole('textbox', { name:'Сообщение', exact:true })
  const original = await composer.inputValue()
  await composer.fill('Synthetic retained header draft')
  const search = header.getByRole('button', { name:'Найти сообщение', exact:true })
  await expect(search).toHaveAttribute('aria-expanded','false')
  await search.click()
  await expect(search).toHaveAttribute('aria-expanded','true')
  const id = await search.getAttribute('aria-controls')
  assert.ok(id)
  await expect(page.locator(`[id="${id}"]`)).toBeVisible()
  const close = conversation.getByRole('button', { name:kind==='TEXT'?'Закрыть поиск в канале':'Закрыть поиск в диалоге', exact:true })
  await close.click(); await expect(search).toBeFocused()
  await expect(search).toHaveAttribute('aria-expanded','false')
  const overflow = header.getByRole('button', { name:'Другие действия', exact:true })
  await overflow.focus(); await overflow.press('ArrowDown')
  await expect(conversation.getByRole('menuitem', { name:'Найти сообщение', exact:true })).toBeFocused()
  await page.screenshot({ path:input.directory+`/header-${kind.toLowerCase()}-overflow.png` })
  await conversation.getByRole('menuitem', { name:'Файлы беседы', exact:true }).click()
  await expect(conversation.locator('#conversation-files-title')).toBeFocused()
  await conversation.getByRole('button', { name:'Закрыть файлы беседы', exact:true }).click()
  await expect(overflow).toBeFocused()
  await expect(header.locator('h2')).toHaveText(title)
  await expect(composer).toHaveValue('Synthetic retained header draft')
  await composer.fill(original)
  await page.screenshot({ path:input.directory+`/header-${kind.toLowerCase()}-returned.png` })
  report.header_actions ??= {}
  report.header_actions[kind] = { search_expanded_and_linked:true, keyboard_overflow:true, files_focus_and_return:true, same_conversation_and_draft:true }
  console.log(`stage=header-${kind.toLowerCase()}-accepted`)
}

export async function voiceHeaderSearch(page, input, report) {
  const header=page.locator('.voice-room > .conversation-header')
  const title=await header.locator('h2').textContent()
  const search=header.getByRole('button',{name:'Найти сообщение',exact:true})
  await expect(search).toHaveAttribute('aria-expanded','false')
  await search.click(); await expect(search).toHaveAttribute('aria-expanded','true')
  await expect(search).toHaveAttribute('aria-controls','search-aside-panel')
  const aside=page.getByTestId('search-aside-panel')
  await expect(aside).toBeVisible()
  await aside.getByRole('button',{name:'Каналы и люди',exact:true}).click()
  await page.screenshot({path:input.directory+'/header-voice-search-navigation.png'})
  await aside.getByRole('button',{name:'Закрыть поиск',exact:true}).click()
  await expect(aside).toHaveCount(0)
  await expect(search).toHaveAttribute('aria-expanded','false')
  await expect(header.locator('h2')).toHaveText(title)
  report.header_actions ??= {}
  report.header_actions.VOICE={ external_search_state:true, navigation_search_close:true, same_selected_voice_channel:true }
  console.log('stage=header-voice-search-accepted')
}
