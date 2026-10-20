import assert from 'node:assert/strict'
import { api, expect, login, select, owned } from './fixture.mjs'
import { mutationSession } from './mutation_session.mjs'
async function calls() {
  const response=await fetch('http://127.0.0.1:4820/metrics')
  return (await response.text()).split('\n').filter(line=>line.startsWith('voice_platform_sfu_room_service_calls_total{'))
    .reduce((sum,line)=>sum+Number(line.split(' ').at(-1)),0)
}
export async function cacheAcl(page,fixture,input,report) {
  const browser=page.context().browser(), context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:900}})
  try {
    const member=await context.newPage()
    await login(member,'qa_unread_member',input.password)
    await select(member,'NextVoice')
    await member.getByRole('button',{name:'Без микрофона',exact:true}).click()
    await expect(member.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён',{timeout:25000})
    const present=async()=>Boolean((await api(page,'/voice/participants')).body.channels.some(room=>room.participants.some(person=>person.account_id===fixture.member)))
    await expect.poll(present,{timeout:10000}).toBe(true)
    const receipt = {}, database = await mutationSession(owned('db','inspect','$owned','--format','{{.Id}}'), fixture.member)
    try { for (const action of ['block','revoke']) {
      await page.waitForTimeout(300)
      await api(page,'/voice/participants')
      const before=await calls()
      await database.mutate(action)
      assert.equal(await present(),false,'Cached SFU metadata exposed a blocked account or revoked lease')
      receipt[action+'_removed_with_fresh_snapshot']=(await calls())===before
      assert.equal(receipt[action+'_removed_with_fresh_snapshot'],true,'Fresh-TTL witness expired before the database recheck')
      if (action==='block') { await database.mutate('unblock'); await expect.poll(present).toBe(true) }
    } } finally { await database.close() }
    report.sfu_fresh_acl=receipt
  } finally { await context.close(); await page.bringToFront() }
}
