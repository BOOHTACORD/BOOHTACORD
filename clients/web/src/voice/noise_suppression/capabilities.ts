/** Checks only capability; a PASS never claims acoustic quality. */
export function supportsRnnoise(): boolean {
  return typeof window !== 'undefined' && window.isSecureContext === true &&
    typeof WebAssembly !== 'undefined' && typeof AudioContext !== 'undefined' &&
    typeof AudioWorkletNode !== 'undefined' && 'audioWorklet' in AudioContext.prototype
}
export function supportedContextRate(context: Pick<AudioContext, 'sampleRate'>): boolean {
  return context.sampleRate === 48000
}
/** Build-time flag: changing it requires a fresh bundle; stored preferences survive. */
export function rnnoiseReleaseEnabled(): boolean {
  return import.meta.env.VITE_RNNOISE_ENABLED !== 'false'
}
/** Research opt-in only; assets and release acceptance are not yet supplied. */
export function deepfilterReleaseEnabled(): boolean {
  return import.meta.env.VITE_DEEPFILTER_ENABLED === 'true'
}
