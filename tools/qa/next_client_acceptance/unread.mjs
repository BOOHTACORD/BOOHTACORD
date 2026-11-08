import assert from 'node:assert/strict'
import { api, channel, expect, seed, select, sql, status } from './fixture.mjs'
import { whileWindowHidden } from './window_visibility.mjs'
export async function unread(page, browser, fixture, input, report) {
  const results = []
  fixture.a = await channel(page, fixture.category, 'NextUnread')
  const member = await api(page, '/auth/register', 'POST', { login:'qa_unread_member', password:input.password }); status(member,201)
  fixture.member = member.body.id
  const dm = await api(page,'/direct-messages','POST',{participant_id:fixture.member}); status(dm,201); fixture.dm=dm.body.id
  for (const kind of ['CHANNEL','DIRECT_MESSAGE']) {
    const data = seed(fixture, kind)
    const endpoint = kind==='CHANNEL' ? `/channels/${data.scope}/messages` : `/direct-messages/${data.scope}/messages`
    let cursor = data.ids[0], collected = []
    do {
      const result = await api(page, endpoint+'?after='+cursor+'&limit=20'); status(result,200)
      collected.push(...result.body.messages.map(item => item.id)); cursor = result.body.next_cursor
    } while (cursor)
    assert.equal(new Set(collected).size, 120, 'Actual PostgreSQL forward pages lost or duplicated rows')
    const cursorTable = kind==='CHANNEL' ? 'channel_read_cursors' : 'direct_message_read_cursors'
    const cursorTarget = kind==='CHANNEL' ? 'channel_id' : 'direct_message_id'
    sql(`DELETE FROM ${cursorTable} WHERE account_id='${fixture.admin}' AND ${cursorTarget}='${data.scope}'`)
    await page.reload()
    if (kind==='CHANNEL') await select(page, 'NextUnread')
    else {
      await page.getByRole('button', { name: 'Личные', exact: true }).click()
      await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'qa_unread_member' }).click()
    }
    const read = () => sql(`SELECT COALESCE((SELECT message_id::text FROM ${cursorTable} WHERE account_id='${fixture.admin}' AND ${cursorTarget}='${data.scope}'),'')`)
    const list = page.locator(kind==='CHANNEL' ? '.text-conversation .message-list' : '.direct-message-conversation .message-list')
    await expect(page.getByText('Есть непрочитанные сообщения.', { exact:true })).toHaveCount(0)
    await expect(page.getByTestId('search-message-context')).toHaveCount(0)
    await expect.poll(read).toBe('')
    const firstUnread = list.locator(`[data-message-id="${data.ids[0]}"]`)
    for (let i=0; i<24 && await firstUnread.count()===0; i++) {
      const older = list.getByRole('button', { name:'Показать предыдущие сообщения', exact:true })
      if (!await older.count()) break
      await older.click()
      await list.evaluate(viewport => { viewport.scrollTop=0 })
      await page.waitForTimeout(150)
    }
    await list.evaluate(viewport => { viewport.scrollTop=0 })
    await page.waitForTimeout(150)
    if (await firstUnread.count()) await firstUnread.scrollIntoViewIfNeeded()
    await expect(firstUnread).toBeVisible()
    await list.evaluate(viewport => viewport.dispatchEvent(new Event('scroll')))
    await expect.poll(read).not.toBe('')
    const firstVisibleRead = data.ids.indexOf(read())
    assert.ok(firstVisibleRead>=0 && firstVisibleRead<35, `Read cursor ${read()} must stop at the visible oldest page, not skip unseen messages`)
    const resumeTop=await list.evaluate(viewport=>viewport.scrollTop)
    const beforeBackground = read()
    await whileWindowHidden(page, async () => {
      await list.evaluate(viewport => { viewport.scrollTop=viewport.scrollHeight; viewport.dispatchEvent(new Event('scroll')) })
      await page.waitForTimeout(200)
      assert.equal(read(), beforeBackground, 'Background window advanced cursor')
    })
    await list.evaluate((viewport,top) => { viewport.scrollTop=top; viewport.dispatchEvent(new Event('scroll')) },resumeTop)
    for (let step=0;step<40;step++) {
      const previousIndex=data.ids.indexOf(read())
      if (previousIndex===data.ids.length-1) break
      await list.evaluate(viewport => {
        viewport.scrollTop=Math.min(viewport.scrollHeight-viewport.clientHeight,viewport.scrollTop+Math.max(120,viewport.clientHeight*.35))
        viewport.dispatchEvent(new Event('scroll'))
      })
      await expect.poll(()=>data.ids.indexOf(read())).toBeGreaterThan(previousIndex)
    }
    await expect.poll(read).toBe(data.ids[120])
    await page.screenshot({ path: input.directory+'/unread-'+kind.toLowerCase()+'.png' })
    if (kind==='CHANNEL') {
      await select(page,'NextB'); await select(page,'NextUnread')
      await expect(page.getByRole('heading',{name:'Контекст найденного сообщения',exact:true})).toHaveCount(0)
      await expect.poll(read).toBe(data.ids[120])
    }
    results.push({ kind, postgres_forward_rows:120, normal_history:true, unread_banner_removed:true, first_unread_requires_visibility:true,
      first_unread_visible_advances_cursor:true, background_read_blocked:true, visible_tail_advances:true })
  }
  report.unread = results
}
