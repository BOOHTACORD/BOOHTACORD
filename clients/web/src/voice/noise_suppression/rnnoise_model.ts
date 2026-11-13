export interface RnnoiseModelIdentity {
  version: string
  sourceCommit: string
  sourceArchiveSha256: string
  modelSha256: string
  modelId: string
  manifestPath: string
}

export const rnnoiseModels: Readonly<Record<'v01' | 'v02', Readonly<RnnoiseModelIdentity>>> = {
  v01: {
    version: 'v0.1-cdf196b',
    sourceCommit: 'cdf196b1e9de2f8ff1003328ebf9a4316477429d',
    sourceArchiveSha256: 'a6f3bd89c5c12546d049bcdcf6d1b58c301fd9c811e760f3087b036a93501d98',
    modelSha256: 'f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95',
    modelId: 'rnnoise-stock-v0.1',
    manifestPath: '/audio/rnnoise/v0.1-cdf196b/rnnoise-manifest.json',
  },
  v02: {
    version: 'v0.2-904a876',
    sourceCommit: '904a876dce1f9ab8860c0a5000ed151f9f6eef58',
    sourceArchiveSha256: 'e4a17eb1493b7551f9f7781d2acc67b8847d6ed7c4b64db0fd62c017021ae1ec',
    modelSha256: '522b6a64fded05bf85e58c06206eafe57ce7d94f3af58c725b17628b481d7890',
    modelId: 'rnnoise-stock-v0.2',
    manifestPath: '/audio/rnnoise/v0.2-904a876/rnnoise-manifest.json',
  },
}

/** The newer model stays disabled until release assets and acceptance are ready. */
export function selectRnnoiseModel(flag: unknown): Readonly<RnnoiseModelIdentity> {
  return flag === 'true' ? rnnoiseModels.v02 : rnnoiseModels.v01
}
