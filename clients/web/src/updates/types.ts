export type UpdateResult = 'identity_unknown' | 'check_unavailable' | 'no_published_target' | 'unsupported_environment' | 'identity_conflict' | 'up_to_date' | 'update_available' | 'current_ahead'
export type UpdateState = 'published' | 'unconfigured' | 'disabled'

export interface LocalIdentity {
  release_id: string
  release_order: number
  platform?: string
  version?: string
  native_build?: string | null
  installed_version?: string
  installed_build?: string
  package_name?: string
  expected_package_name?: string
}

export interface EvaluationEnvironment { os_version: string; arch: string; now?: string }
export interface UpdateRequirements { min_os_version?: string; min_android_sdk?: number; supported_arches: string[] }
export interface UpdateAction { kind: 'reload' | 'open_download_page' | 'open_store' | 'open_instructions'; url: string | null }
export interface UpdateTarget {
  release_id: string; release_order: number; minimum_release_order?: number | null; version?: string; native_build?: string | null
  priority?: 'normal' | 'important'; published_at?: string; expires_at?: string
  summary?: string; release_notes_url?: string | null; requirements: UpdateRequirements; action?: UpdateAction
}
export interface UpdatePolicy {
  application_family?: string; catalog_revision?: number; platform?: string; distribution?: string
  channel?: string; arch?: string; state?: UpdateState; target?: UpdateTarget | null
}
