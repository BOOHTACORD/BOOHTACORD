import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { api, channel, expect, seed, select, sql, status } from './fixture.mjs'
import { cacheAcl } from './cache_acl.mjs'
import { navigationFixture } from './navigation_fixture.mjs'
async function position(page) {
  return page.locator('.message-history-wrap .message-list').evaluate(list => {
    const top=list.getBoundingClientRect().top
    const row=[...list.querySelectorAll('[data-message-id]')].find(row=>row.getBoundingClientRect().bottom>top)
    return { id:row?.dataset.messageId, offset:row?.getBoundingClientRect().top-top }
  })
}
export async function navigation(page, fixture, input, report) {
  fixture=await navigationFixture(fixture,()=>channel(page,fixture.category,'NextNavigation'),seed,async(fresh,messageId)=>{
    // Recreate unread acceptance's verified baseline in this new scope before
    // adding the genuinely unseen tail; do not inherit its persisted DOM context.
    const cursor=await api(page,`/channels/${fresh.a}/read-cursor`,'PUT',{message_id:messageId})
    status(cursor,200)
    const persisted=sql(`SELECT message_id FROM channel_read_cursors WHERE account_id='${fresh.admin}' AND channel_id='${fresh.a}'`)
    assert.equal(cursor.body.message_id,persisted)
    return persisted
  })
  const voice = await channel(page,fixture.category,'NextVoice','VOICE')
  await select(page,'NextVoice')
  await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён',{timeout:25000})
  const lease=()=>sql(`SELECT id FROM voice_leases WHERE user_id='${fixture.admin}' AND revoked_at IS NULL`)
  const originalLease=lease(); assert.ok(originalLease)
  await cacheAcl(page,fixture,input,report)
  const ids=sql(`SELECT id FROM messages WHERE channel_id='${fixture.a}' ORDER BY created_at,id LIMIT 1`).split('\n')
  const tail=Array.from({length:50},(_,i)=>`('${randomUUID()}','${fixture.a}','${fixture.member}','${randomUUID()}','QA unseen tail',TIMESTAMPTZ '2026-01-01' + INTERVAL '${200+i} seconds')`)
  sql(`INSERT INTO messages(id,channel_id,author_id,client_message_id,body,created_at) VALUES ${tail.join(',')}`)
  const reply=await api(page,`/channels/${fixture.a}/messages`,'POST',{
    client_message_id:randomUUID(),reply_to_id:ids[0],body:'QA navigation reply',
  });status(reply,201)
  const historyRequest=page.waitForResponse(response=>new URL(response.url()).pathname===`/api/v1/channels/${fixture.a}/messages`&&response.request().method()==='GET')
  await select(page,'NextNavigation')
  const historyResponse=await historyRequest;assert.equal(historyResponse.status(),200)
  const history=await historyResponse.json();assert.ok(history.messages.some(message=>message.id===reply.body.id),'Latest channel history omitted the newly created reply')
  const list=page.locator('.message-history-wrap .message-list')
  await expect(list).toBeVisible({timeout:20000})
  // A completed HTTP response is not a committed virtualized history. Stay at
  // latest until the new row renders, then choose the origin for the return check.
  await list.evaluate(view=>{view.scrollTop=view.scrollHeight;view.dispatchEvent(new Event('scroll'))})
  const replyRow=list.locator(`[data-message-id="${reply.body.id}"]`)
  await expect(replyRow).toBeVisible({timeout:20000})
  await list.evaluate(view=>{view.scrollTop=Math.max(0,view.scrollHeight-view.clientHeight-200);view.dispatchEvent(new Event('scroll'))})
  const replyPreview=replyRow.locator('.reply-preview')
  await expect(replyPreview).toBeVisible({timeout:20000})
  await replyPreview.scrollIntoViewIfNeeded()
  const before=await position(page)
  await replyPreview.click()
  const context=page.getByTestId('search-message-context')
  await expect(context.locator('[data-search-anchor]')).toBeFocused()
  assert.equal(lease(),originalLease,'Message navigation replaced voice lease')
  await context.getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  const after=await position(page)
  assert.equal(after.id,before.id,'Reply return lost the originating scroll anchor')
  assert.ok(Math.abs(after.offset-before.offset)<=2,'Reply return lost its offset')
  await expect(replyPreview).toBeFocused()
  sql(`UPDATE messages SET body='',deleted_at=now() WHERE id='${ids[0]}'`)
  await replyPreview.click()
  await expect(context.locator('[data-search-anchor]')).toContainText('Сообщение удалено.')
  const tombstone=await api(page,`/channels/${fixture.a}/messages?at=${ids[0]}&limit=20`);status(tombstone,200)
  assert.equal(tombstone.body.messages[0].body,'')
  await context.getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  await page.locator('.guild-search-button').click()
  const search=page.getByTestId('search-panel')
  await search.getByLabel('Запрос',{exact:true}).fill('QA history 1')
  await search.getByRole('button',{name:'Найти',exact:true}).click()
  // A new SQL-only row has never been delivered or rendered in this browser.
  // It witnesses a genuinely unseen tail, independently of earlier reply scrolling.
  const unseen=sql(`INSERT INTO messages(id,channel_id,author_id,client_message_id,body,created_at) VALUES(gen_random_uuid(),'${fixture.a}','${fixture.member}',gen_random_uuid(),'QA unseen search tail',now()+INTERVAL '1 second') RETURNING id`).split('\n')[0]
  const priorCursor=sql(`SELECT message_id FROM channel_read_cursors WHERE account_id='${fixture.admin}' AND channel_id='${fixture.a}'`)
  assert.ok(priorCursor);assert.notEqual(priorCursor,unseen)
  await expect(page.locator(`[data-message-id="${unseen}"]`)).toHaveCount(0)
  await search.getByRole('button',{name:/Открыть сообщение от/}).first().click()
  await expect(context.locator('[data-search-anchor]')).toBeFocused()
  assert.equal(sql(`SELECT message_id FROM channel_read_cursors WHERE account_id='${fixture.admin}' AND channel_id='${fixture.a}'`),priorCursor,'Search context consumed unseen history')
  assert.equal(lease(),originalLease)
  await page.screenshot({path:input.directory+'/search-context-voice-retained.png'})
  await context.getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  // This DM is between two synthetic members. Administrator status never grants reading.
  const other=await api(page,'/auth/register','POST',{login:'qa_private_member',password:input.password});status(other,201)
  const foreign=sql(`INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES(gen_random_uuid(),LEAST('${fixture.member}'::uuid,'${other.body.id}'::uuid),GREATEST('${fixture.member}'::uuid,'${other.body.id}'::uuid)) RETURNING id` ).split('\n')[0]
  const denied=await api(page,`/direct-messages/${foreign}/messages?at=${ids[0]}`);status(denied,404)
  assert.equal(JSON.stringify(denied.body).includes('qa_private_member'),false)
  await page.getByTestId('voice-dock').getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
  report.navigation={loaded_reply_route_preserved:true,old_reply_at:true,return_anchor_offset:true,keyboard_focus:true,
    tombstone_body_hidden:true,search_unseen_tail_retained:true,foreign_dm_admin_denied:true,dm_name_not_disclosed:true,voice_lease_preserved:true}
}
