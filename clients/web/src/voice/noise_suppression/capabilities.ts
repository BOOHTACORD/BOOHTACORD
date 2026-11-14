/** Checks only capability; a PASS never claims acoustic quality. */
export function supportsRnnoise(): boolean {
  return typeof window !== 'undefined' && window.isSecureContext === true &&
    typeof WebAssembly !== 'undefined' && typeof AudioContext !== 'undefined' &&
    typeof AudioWorkletNode !== 'undefined' && 'audioWorklet' in AudioContext.prototype
}
export function supportedContextRate(context: Pick<AudioContext, 'sampleRate'>): boolean {
  return context.sampleRate === 48000
}
/** Eligibility is measured off the capture thread; this is not acoustic proof. */
export async function selectAutoEngine(input: {
  v02: boolean; supported: boolean; deepfilterResearch?: boolean
  probe?: (engine: 'rnnoise' | 'deepfilter') => Promise<boolean>
}): Promise<'browser' | 'rnnoise' | 'deepfilter'> {
  if (!input.supported || !input.probe) return 'browser'
  const candidates: ('rnnoise' | 'deepfilter')[] = []
  if (input.deepfilterResearch) candidates.push('deepfilter')
  if (input.v02) candidates.push('rnnoise')
  for (const engine of candidates) {
    try { if (await input.probe(engine) === true) return engine } catch { /* Try the next safe candidate. */ }
  }
  return 'browser'
}
/** Build-time flag: changing it requires a fresh bundle; stored preferences survive. */
export function rnnoiseReleaseEnabled(): boolean {
  return import.meta.env.VITE_RNNOISE_ENABLED !== 'false'
}
/** Research opt-in only; assets and release acceptance are not yet supplied. */
export function deepfilterReleaseEnabled(): boolean {
  return import.meta.env.VITE_DEEPFILTER_ENABLED === 'true'
}
