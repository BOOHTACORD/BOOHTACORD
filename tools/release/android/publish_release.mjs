import { GitHubApiError, apiUrl, isRetryable, maxAttempts, retryDelay, sendJson } from './github_api.mjs'
import { uploadAssets } from './upload_assets.mjs'

const defaultApiRoot = 'https://api.github.com'

export async function publishGitHubRelease({
  tag,
  title,
  body,
  assets,
  token,
  owner = 'BOOHTACORD',
  repo = 'BOOHTACORD',
  apiRoot = defaultApiRoot,
  fetchImpl = fetch,
  sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
}) {
  if (!token) throw new Error('GITHUB_TOKEN is required')
  if (!/^(android|windows)-v\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$/.test(tag ?? '')) {
    throw new Error('Release tag must use the android-vX.Y.Z or windows-vX.Y.Z form')
  }
  if (!Array.isArray(assets) || assets.length === 0) {
    throw new Error('At least one release asset is required')
  }

  const repositoryPath = `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`
  const releaseCollectionUrl = apiUrl(apiRoot, `${repositoryPath}/releases`)
  const tagReleaseUrl = apiUrl(
    apiRoot,
    `${repositoryPath}/releases/tags/${encodeURIComponent(tag)}`,
  )

  async function findRelease() {
    try {
      return await sendJson({ fetchImpl, token, url: tagReleaseUrl })
    } catch (error) {
      if (error instanceof GitHubApiError && error.status === 404) return null
      throw error
    }
  }

  let release = null
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    release = await findRelease()
    if (release) break

    try {
      release = await sendJson({
        fetchImpl,
        token,
        url: releaseCollectionUrl,
        method: 'POST',
        body: {
          tag_name: tag,
          name: title,
          target_commitish: 'master',
          body,
          draft: false,
          prerelease: false,
        },
      })
      break
    } catch (error) {
      // A lost response or 409 may mean the release was created successfully.
      try {
        release = await findRelease()
      } catch (_) {
        // Keep the original create error; never include a token or response body.
      }
      if (release) break
      if (!isRetryable(error) || attempt === maxAttempts) throw error
      await sleep(retryDelay(attempt))
    }
  }
  if (!release?.id || !release.upload_url) throw new Error(`GitHub did not return release metadata for ${tag}`)
  if (release.tag_name && release.tag_name !== tag) {
    throw new Error('GitHub returned a release for a different tag')
  }

  const uploaded = await uploadAssets({ release, assets, token, owner, repo, apiRoot, fetchImpl, sleep })
  return { release, uploaded }
}
