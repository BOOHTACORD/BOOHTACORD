import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { publishGitHubRelease } from '../android/publish_release.mjs'

export function releaseMetadata(tag) {
  const version = tag?.replace(/^windows-v/, '')
  if (!version || `windows-v${version}` !== tag) throw new Error('Release tag is missing')
  return {
    title: `BOOHTACORD Windows ${version}`,
    body: [
      `Windows x64 distribution of BOOHTACORD ${version}.`,
      '',
      'For a per-user installation, run the Setup.exe asset once. Future compatible releases can then be prepared inside the client.',
      'The ZIP remains available for manual portable use; it does not become an installed updater automatically.',
      'The archive includes artifact-manifest.json and SHA256SUMS for integrity verification.',
      '',
      'The full NUPKG is the in-app update package; users migrating from an older ZIP should use Setup.exe.',
      'The executable signing state is measured in artifact-manifest.json.',
    ].join('\n'),
  }
}

function parseArgs(args) {
  const parsed = { assets: [] }
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--tag') parsed.tag = args[++index]
    else if (args[index] === '--asset') parsed.assets.push(args[++index])
    else throw new Error(`Unknown argument: ${args[index]}`)
  }
  return parsed
}

async function main() {
  const { tag, assets } = parseArgs(process.argv.slice(2))
  const [owner, repo] = (process.env.GITHUB_REPOSITORY ?? '').split('/')
  if (!owner || !repo) throw new Error('GITHUB_REPOSITORY is missing or invalid')
  const metadata = releaseMetadata(tag)
  const { release, uploaded } = await publishGitHubRelease({
    tag, ...metadata, assets, token:process.env.GITHUB_TOKEN, owner, repo,
  })
  for (const asset of uploaded) console.log(`${asset.alreadyPresent ? 'Verified existing' : 'Uploaded'} ${asset.name}`)
  console.log(`GitHub release: ${release.html_url ?? `https://github.com/${owner}/${repo}/releases/tag/${tag}`}`)
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1 })
}
