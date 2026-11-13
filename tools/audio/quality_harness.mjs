// Existing RNNoise invocation remains the default. DeepFilterNet research
// must explicitly supply the pinned, independently built local artifacts.
if (process.argv[2] === '--deepfilter-research') {
  await import('./research_dfn_web/quality.mjs')
} else {
  await import('./rnnoise_quality.mjs')
}
