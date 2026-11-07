import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
const root = process.cwd(), require = createRequire(path.join(root, 'clients/web/package.json'))
const { chromium, expect } = require('@playwright/test')
const defines = JSON.parse(fs.readFileSync(process.env.QA_DEFINES_FILE, 'utf8').replace(/^\uFEFF/, ''))
if (defines.QA_API_BASE !== 'https://localhost:4810/api/v1') throw Error('Owned endpoint required')
const destination = path.resolve('.out/join-sounds-web'); fs.mkdirSync(destination, { recursive: true })
const browser = await chromium.launch({ headless: true })
try {
  for (const width of [1440,393]) {
    const context = await browser.newContext({ ignoreHTTPSErrors:true, viewport:{width,height:900} })
    const login = await context.request.post(defines.QA_API_BASE+'/auth/login', { headers:{origin:'https://localhost:4810'}, data:{login:'qa_admin',password:defines.QA_PASSWORD} })
    if (!login.ok()) throw Error('Synthetic login failed')
    const profile = await (await context.request.get(defines.QA_API_BASE+'/me')).json()
    const headers = {origin:'https://localhost:4810','X-Voice-Sound-Account':profile.account_id}
    await context.request.delete(defines.QA_API_BASE+'/me/join-sound',{headers})
    const page = await context.newPage()
    page.on('pageerror', e => console.log('BROWSER_ERROR', e.name))
    page.on('response', r => { if (r.url().includes('/me/join-sound')) console.log('SOUND_HTTP', r.request().method(), r.status()) })
    await page.addInitScript(() => {
      window.__qaAudio = {plays:0,peak:0}
      const original = HTMLMediaElement.prototype.play
      HTMLMediaElement.prototype.play = function(...args) {
        return original.apply(this,args).then(async () => {
          window.__qaAudio.plays++
          const context = new AudioContext(); await context.resume()
          const source = context.createMediaElementSource(this), analyser = context.createAnalyser()
          source.connect(analyser); analyser.connect(context.destination)
          const samples = new Float32Array(analyser.fftSize)
          const timer = setInterval(() => { analyser.getFloatTimeDomainData(samples); window.__qaAudio.peak=Math.max(window.__qaAudio.peak,...samples.map(Math.abs)) },10)
          setTimeout(() => { clearInterval(timer); void context.close() },3500)
        })
      }
    })
    await page.goto('https://localhost:4810', {waitUntil:'domcontentloaded'})
    const open = page.getByRole('button',{name:'Открыть настройки профиля',exact:true})
    if (!await open.isVisible()) {
      const menu = page.getByRole('button',{name:/Открыть навигацию|Открыть меню/}).first()
      if (await menu.isVisible()) await menu.click()
    }
    await open.click()
    const panel = page.getByRole('region',{name:'Персональная мелодия входа',exact:true})
    await expect(panel).toBeVisible()
    const wav = Buffer.alloc(44+24000)
    wav.write('RIFF',0);wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(24000,24);wav.writeUInt32LE(48000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(24000,40)
    for (let i=0;i<12000;i++) wav.writeInt16LE(Math.round(Math.sin(i*2*Math.PI*440/24000)*15000),44+i*2)
    await expect(panel.locator('input[type=file]')).toBeEnabled()
    const upload = page.waitForResponse(r => r.url().endsWith('/me/join-sound') && r.request().method()==='POST')
    await panel.locator('input[type=file]').setInputFiles({name:'qa.wav',mimeType:'audio/wav',buffer:wav})
    expect((await upload).status()).toBe(201)
    await expect(panel.getByRole('checkbox')).not.toBeChecked()
    await panel.getByRole('checkbox').check()
    await expect(panel.getByRole('checkbox')).toBeChecked()
    await panel.getByRole('button',{name:'Прослушать мелодию'}).click()
    await expect.poll(() => page.evaluate(() => window.__qaAudio.peak),{timeout:10000}).toBeGreaterThan(.005)
    await expect(panel.getByText('Обрабатываем мелодию…')).toHaveCount(0)
    await panel.screenshot({path:path.join(destination,`profile-${width}.png`)})
    await panel.getByRole('button',{name:'Удалить мелодию'}).click()
    await expect(panel.getByRole('button',{name:'Прослушать мелодию'})).toHaveCount(0)
    await page.getByRole('tab',{name:'Уведомления',exact:true}).click()
    const sounds = page.getByRole('region',{name:'Звуки голосового канала',exact:true})
    await expect(sounds.getByRole('slider')).toBeEnabled()
    await sounds.getByRole('checkbox',{name:'Включить звуковые уведомления'}).uncheck()
    await expect(sounds.getByRole('button',{name:'Прослушать: Кто-то вошёл',exact:true})).toBeDisabled()
    await sounds.getByRole('checkbox',{name:'Включить звуковые уведомления'}).check()
    await sounds.getByRole('button',{name:'Прослушать: Кто-то вошёл',exact:true}).click()
    await expect.poll(() => page.evaluate(() => window.__qaAudio.plays)).toBeGreaterThanOrEqual(2)
    await sounds.screenshot({path:path.join(destination,`settings-${width}.png`)})
    await context.close(); if (width === 1440) await new Promise(resolve => setTimeout(resolve,10500)); console.log(`WEB_JOIN_SOUND_PASS width=${width} upload=real-worker playback=decoded-pcm`)
  }
} finally { await browser.close() }
