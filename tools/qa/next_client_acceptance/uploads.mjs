import assert from 'node:assert/strict'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { expect, select, owned, sql, freshUploadWindow } from './fixture.mjs'
import { fixtureFile } from './input_files.mjs'
async function reserved() {
  const response = await fetch('http://127.0.0.1:4820/metrics')
  const value = (await response.text()).match(/^voice_platform_attachment_upload_reserved_bytes (\S+)$/m)
  assert.ok(value, 'Actual reservation metric missing')
  const bytes = Number(value[1]); assert.ok(Number.isSafeInteger(bytes) && bytes >= 0, 'Invalid reservation metric')
  return bytes
}
async function selectFiles(page, selector, files, stage) {
  const input = page.locator(selector)
  await expect(input).toBeEnabled()
  console.log(`stage=upload-input-ready-${stage}`)
  await input.setInputFiles(files)
  console.log(`stage=upload-files-selected-${stage}`)
}
export async function uploads(page, input, report, fixture, freshPage) {
  const file = (name,size) => fixtureFile(input.files_directory,name,size)
  await select(page, 'NextA')
  let picker = page.locator('.attachment-picker'), queue = picker.locator('[data-upload-status]')
  async function independentPublication() {
    await freshUploadWindow(page)
    page = await freshPage()
    picker = page.locator('.attachment-picker'); queue = picker.locator('[data-upload-status]')
    await select(page, 'NextA')
  }
  let count = 0
  page.on('request', request => { if (request.method()==='POST' && /\/attachments$/.test(new URL(request.url()).pathname)) count++ })
  if (input.limited) {
    owned('keeper', 'exec', '$owned', 'dd', 'if=/dev/zero', 'of=/attachments/qa-capacity-fill', 'bs=1000000', 'count=25')
    await selectFiles(page, '#message-attachments', [file('one.bin', 5_000_000), file('two.bin', 5_000_000), file('three.bin', 25_000_000)], 'capacity-batch')
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(2)
    await expect(picker.locator('[data-upload-status="failed"]')).toHaveCount(1)
    await page.locator('#message-body').fill('QA attachment queue')
    await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeDisabled()
    assert.equal(count, 3)
    owned('keeper', 'exec', '$owned', 'rm', '/attachments/qa-capacity-fill')
    await picker.getByRole('button', { name: 'Повторить загрузку three.bin', exact: true }).click()
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(3)
    assert.equal(count, 4, 'Successful IDs were uploaded again')
    await select(page, 'NextB'); await select(page, 'NextA')
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(3)
    await expect(page.locator('#message-body')).toHaveValue('QA attachment queue')
    await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
    await expect(queue).toHaveCount(0)
    assert.equal(sql(`SELECT count(*) FROM attachments WHERE channel_id='${fixture.a}' AND state='ATTACHED'`),'3')
    await page.screenshot({ path: input.directory+'/upload-retried-published.png' })
    report.uploads = { actual_third_file_507: true, retry_only_failed: true, prepared_ids_survive_scope: true, published: true }
  } else {
    const session = await page.context().newCDPSession(page)
    await session.send('Network.enable')
    await session.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: 10_000_000, uploadThroughput: 100_000 })
    await selectFiles(page, '#message-attachments', file('cancel.bin', 25_000_000), 'cancel')
    await expect.poll(reserved, { timeout: 15000 }).toBe(25_000_000)
    await expect(picker.locator('progress')).toBeVisible()
    await expect.poll(async()=>Number(await picker.locator('progress').getAttribute('value'))).toBeGreaterThan(0)
    await picker.getByRole('button', { name: 'Отменить загрузку cancel.bin', exact: true }).click()
    await expect.poll(reserved, { timeout: 15000 }).toBe(0)
    assert.equal(owned('keeper', 'exec', '$owned', 'sh', '-c', 'find /attachments/staging -type f | wc -l'), '0')
    await selectFiles(page, '#message-attachments', file('switch-scope.bin',25_000_000), 'scope-switch')
    await expect.poll(reserved,{timeout:15000}).toBe(25_000_000)
    await select(page,'NextB')
    await expect.poll(reserved,{timeout:15000}).toBe(0)
    await expect(queue).toHaveCount(0)
    await select(page,'NextA'); await expect(queue).toHaveCount(0)
    assert.equal(sql("SELECT count(*) FROM attachments WHERE original_name IN ('cancel.bin','switch-scope.bin')"),'0')
    await session.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 })
    await session.detach()
    await independentPublication()
    mkdirSync(input.files_directory,{recursive:true})
    const paths = Array.from({length:10},(_,i)=>join(input.files_directory,`batch-${i}.bin`))
    for (const path of paths) writeFileSync(path,Buffer.alloc(1_000_000),{flag:'wx'})
    await selectFiles(page, '#message-attachments', paths, 'ten-file-batch')
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(10, { timeout: 60000 })
    await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeEnabled()
    await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
    await expect(queue).toHaveCount(0)
    assert.equal(sql(`SELECT count(*) FROM attachments WHERE channel_id='${fixture.a}' AND state='ATTACHED'`),'10')
    await independentPublication()
    await page.getByRole('button', { name: 'Личные', exact: true }).click()
    await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'qa_next_member' }).click()
    await selectFiles(page, '#dm-attachments', file('dm-real.bin', 1_000_000), 'direct-message')
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(1)
    await page.locator('.message-composer').evaluate(form=>{
      const dataTransfer=new DataTransfer()
      dataTransfer.items.add(new File([new Uint8Array(1024)],'drop-real.bin'))
      form.dispatchEvent(new DragEvent('drop',{dataTransfer,bubbles:true,cancelable:true}))
    })
    await expect(picker.locator('[data-upload-status="done"]')).toHaveCount(2)
    await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
    await expect(queue).toHaveCount(0)
    assert.equal(sql(`SELECT count(*) FROM attachments WHERE direct_message_id='${fixture.dm}' AND state='ATTACHED'`),'2')
    report.uploads = { actual_abort_releases_reservation: true, staging_files: 0, actual_progress: true,
      ten_1mb_files: true, actual_scope_switch_aborts:true, actual_active_composer_drop:true, successful_text_and_dm_publication: true }
  }
}
