/** Research selection only; performance-based adaptation is not implemented. */
export function selectAutoEngine(input: { v02: boolean, supported: boolean }): 'browser' | 'rnnoise' {
  return input.v02 && input.supported ? 'rnnoise' : 'browser'
}
