import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'
import { publishGitHubRelease } from './publish.mjs'
import { apiRoot, releasePath, release, json, withAsset } from './test_helpers.mjs'

test('rejects without a token or before uploading a conflicting same-name asset', async () => {
  await withAsset(Buffer.from('new-build'), async (asset) => {
    let calls = 0
    const fetchImpl = async () => {
      calls += 1
      return json({ id: 73, tag_name: 'android-v1.0.15' })
    }

    await assert.rejects(
      publishGitHubRelease({
        tag: 'android-v1.0.15', title: 'release', body: '', assets: [asset.path],
        token: '', apiRoot, fetchImpl,
      }),
      /GITHUB_TOKEN is required/,
    )
    assert.equal(calls, 0)

    await assert.rejects(
      publishGitHubRelease({
        tag: 'android-v1.0.15', title: 'release', body: '', assets: [asset.path],
        token: 'write-token', apiRoot,
        fetchImpl: async (url, init = {}) => {
          const parsed = new URL(url)
          if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
            return json(release)
          }
          if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
            return json([{ id: 91, name: asset.name, size: asset.size + 1 }])
          }
          assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
        },
      }),
      /conflicting existing asset/,
    )
  })
})

test('runs the publisher CLI on the current platform and fails closed without its secret', () => {
  const script = fileURLToPath(new URL('./publish.mjs', import.meta.url))
  const result = spawnSync(process.execPath, [
    script,
    '--tag',
    'android-v1.0.15',
    '--asset',
    'not-read-without-a-token.apk',
  ], {
    encoding: 'utf8',
    env: {
      ...process.env,
      GITHUB_REPOSITORY: 'BOOHTACORD/BOOHTACORD',
      GITHUB_TOKEN: '',
    },
  })

  assert.equal(result.status, 1)
  assert.match(result.stderr, /GITHUB_TOKEN is required/)
})

test('rejects a same-size asset with different or unavailable bytes digest', async () => {
  await withAsset(Buffer.from('new-build'), async (asset) => {
    for (const digest of [undefined, `sha256:${'0'.repeat(64)}`]) {
      await assert.rejects(publishGitHubRelease({
        tag: 'android-v1.0.15', title: 'release', body: '', assets: [asset.path],
        token: 'write-token', apiRoot,
        fetchImpl: async (url, init = {}) => {
          if (String(url).includes('/releases/tags/')) return json(release)
          assert.equal(init.method, 'GET')
          return json([{ name: asset.name, size: asset.size, digest }])
        },
      }), /conflicting existing asset/)
    }
  })
})
