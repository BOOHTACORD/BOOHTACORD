import assert from 'node:assert/strict'
import { expect, channel } from '../../client_lifecycle/request.mjs'
import { control } from './observe.mjs'
import { healthy } from './cases.mjs'
import { revokeSession } from './logout.mjs'

export async function cancellation(page,input,room) {
  const entered = () => expect.poll(async () => (await control(page,input.token)).seen).toBe(1)
  const close = () => page.evaluate(() => window.__r2.socket.close())
  const login = async () => {
    await page.getByLabel('Логин',{exact:true}).fill('qa_admin')
    await page.getByLabel('Пароль',{exact:true}).fill(input.password)
    await page.getByRole('button',{name:'Войти',exact:true}).click()
    await expect(page.getByTestId('app-shell')).toBeVisible()
    await channel(page,'R2 Voice',room)
    await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
    await healthy(page)
  }
  await control(page,input.token,'upgrade-stall'); await close(); await entered()
  const started = Date.now()
  await page.getByRole('button',{name:'Повторить связь чата',exact:true}).click()
  await healthy(page); assert.ok(Date.now()-started<5000)
  assert.equal((await control(page,input.token)).cancelled,true)
  for (const mode of ['upgrade-stall','session-late401']) {
    await control(page,input.token,mode); await close(); await entered()
    await page.getByRole('button',{name:'Открыть настройки профиля',exact:true}).click()
    await page.getByRole('tab',{name:'Безопасность',exact:true}).click()
    await page.getByRole('button',{name:'Выйти из аккаунта',exact:true}).click()
    await page.getByRole('dialog',{name:'Подтвердите выход из аккаунта'}).getByRole('button',{name:'Выйти',exact:true}).click()
    await expect(page.getByLabel('Логин',{exact:true})).toBeVisible()
    await login()
    const cookie = (await page.context().cookies()).find(c=>c.httpOnly)?.value
    if(mode==='session-late401') await page.waitForTimeout(13000)
    assert.ok((await page.context().cookies()).find(c=>c.httpOnly)?.value===cookie)
    await healthy(page)
    assert.equal((await control(page,input.token)).cancelled,true)
  }
  await revokeSession(page)
  await expect(page.getByLabel('Логин',{exact:true})).toBeVisible()
  await login()
  return true
}
