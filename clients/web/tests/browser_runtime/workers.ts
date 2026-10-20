import { availableParallelism } from 'node:os'

// Only the marked four-CPU disposable Linux pool expands browser concurrency.
// A separate browser/context per worker keeps route fixtures and native zoom isolated.
export function browserRuntime(env: Record<string, string | undefined> = process.env, cpus = availableParallelism()) {
  const pooled = env.GITHUB_ACTIONS === 'true'
    && env.RUNNER_ENVIRONMENT === 'self-hosted'
    && env.RUNNER_OS === 'Linux'
    && env.BOOHTACORD_EPHEMERAL_GUEST === 'true'
    && cpus === 4
  return { workers: pooled ? 2 : 1, fullyParallel: pooled }
}
