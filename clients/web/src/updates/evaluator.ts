import type { EvaluationEnvironment, LocalIdentity, UpdatePolicy, UpdateResult } from './types'

function versionParts(value: string): number[] | null {
  if (!/^\d+(\.\d+)*$/.test(value)) return null
  return value.split('.').map(Number)
}

function below(current: string, minimum: string): boolean {
  const left = versionParts(current); const right = versionParts(minimum)
  if (!left || !right) return true
  const length = Math.max(left.length, right.length)
  for (let index = 0; index < length; index++) {
    const difference = (left[index] ?? 0) - (right[index] ?? 0)
    if (difference !== 0) return difference < 0
  }
  return false
}

function valid(policy: UpdatePolicy): boolean {
  if (!['published', 'unconfigured', 'disabled'].includes(policy.state ?? '')) return false
  if (policy.state !== 'published') return policy.target === null
  const target = policy.target
  const minimum = target?.minimum_release_order
  if (minimum != null && (!Number.isInteger(minimum) || minimum < 1 || minimum > 2147483647 || minimum > target!.release_order)) return false
  return Boolean(target && /^[A-Za-z0-9._-]{1,96}$/.test(target.release_id) && Number.isInteger(target.release_order) && target.release_order > 0 && Array.isArray(target.requirements?.supported_arches))
}

export function evaluateUpdate(local: LocalIdentity | null, policy: UpdatePolicy, environment: EvaluationEnvironment): UpdateResult {
  if (!local || !local.release_id || !Number.isInteger(local.release_order)) return 'identity_unknown'
  if (!valid(policy)) return 'check_unavailable'
  if (policy.state !== 'published' || !policy.target) return 'no_published_target'
  const target = policy.target
  if (target.expires_at && Date.parse(target.expires_at) <= Date.parse(environment.now ?? new Date().toISOString())) return 'no_published_target'
  const arches = target.requirements.supported_arches
  if (!arches.includes('any') && !arches.includes(environment.arch)) return 'unsupported_environment'
  if (target.requirements.min_os_version && below(environment.os_version, target.requirements.min_os_version)) return 'unsupported_environment'
  if (local.installed_version && local.version && local.installed_version !== local.version) return 'identity_conflict'
  if (local.installed_build && local.native_build && local.installed_build !== local.native_build) return 'identity_conflict'
  if (local.package_name && local.expected_package_name && local.package_name !== local.expected_package_name) return 'identity_conflict'
  if (target.release_id === local.release_id) return 'up_to_date'
  if (target.release_order > local.release_order) return 'update_available'
  if (target.release_order < local.release_order) return 'current_ahead'
  return 'identity_conflict'
}

// This is a presentation decision, not a server authorization check.
export function requiresUpdate(local: LocalIdentity | null, policy: UpdatePolicy, environment: EvaluationEnvironment): boolean {
  if (!valid(policy) || policy.state !== 'published' || !policy.target) return false
  const target = policy.target; const minimum = target.minimum_release_order
  if (minimum == null || (target.expires_at && Date.parse(target.expires_at) <= Date.parse(environment.now ?? new Date().toISOString()))) return false
  if (!local || !local.release_id || !Number.isInteger(local.release_order) || local.release_order < 1) return true
  if (evaluateUpdate(local, policy, environment) === 'identity_conflict') return true
  return local.release_order < minimum
}
