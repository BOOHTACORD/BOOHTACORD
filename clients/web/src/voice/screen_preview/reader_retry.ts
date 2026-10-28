export const screenPreviewPollIntervalMs = 30_000
export const screenPreviewInitialRetryIntervalMs = 1_000
export const screenPreviewInitialRetryLimit = 3

export function screenPreviewRetryDelay(failures: number, random: () => number = Math.random): number {
  const exponent = Math.max(0, Math.min(10, failures - 1))
  const base = Math.min(30_000, 1_000 * 2 ** exponent)
  return Math.min(30_000, Math.round(base * (0.8 + random() * 0.4)))
}
