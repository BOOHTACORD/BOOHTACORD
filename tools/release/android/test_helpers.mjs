import { mkdtemp, rm, stat, writeFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import os from 'node:os'
import path from 'node:path'

export const apiRoot = 'https://api.example.test'
export const releasePath = '/repos/BOOHTACORD/BOOHTACORD'
export const release = {
  id: 73,
  tag_name: 'android-v1.0.15',
  upload_url: 'https://uploads.example.test/repos/BOOHTACORD/BOOHTACORD/releases/73/assets{?name,label}',
}
export const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { 'content-type': 'application/json' },
})

export async function withAsset(content, run) {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'boohtacord-release-test-'))
  const file = path.join(directory, 'BOOHTACORD-android-v1.0.15-arm64-v8a.apk')
  await writeFile(file, content)
  try {
    await run({ path: file, name: path.basename(file), size: (await stat(file)).size,
      digest: `sha256:${createHash('sha256').update(content).digest('hex')}` })
  } finally {
    await rm(directory, { recursive: true, force: true })
  }
}
