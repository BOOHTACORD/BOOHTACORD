import { describe, expect, it } from 'vitest'
import { evaluateUpdate, requiresUpdate } from './evaluator'
import { parsePolicy } from './client'
import type { UpdatePolicy } from './types'

const policy = (minimum: number | null): UpdatePolicy => ({ state:'published', target:{release_id:'r5',release_order:5,minimum_release_order:minimum,requirements:{supported_arches:['any']}} })
const local = (order: number) => ({release_id:`r${order}`,release_order:order})
const environment = {os_version:'browser',arch:'any'}

describe('minimum client release', () => {
 it('requires update below a configured valid minimum', () => {
  expect(requiresUpdate(local(2),policy(4),environment)).toBe(true)
  expect(requiresUpdate(local(4),policy(4),environment)).toBe(false)
  expect(requiresUpdate(local(2),policy(null),environment)).toBe(false)
  expect(evaluateUpdate(local(2),policy(6),environment)).toBe('check_unavailable')
  expect(evaluateUpdate(local(2),policy(0),environment)).toBe('check_unavailable')
 })
 it('fails closed for unknown identity and unsupported environment when minimum is configured', () => {
  expect(requiresUpdate(null,policy(4),environment)).toBe(true)
  const incompatible = { ...policy(4), target:{...policy(4).target!, requirements:{supported_arches:['arm64']}} }
  expect(requiresUpdate(local(2),incompatible,environment)).toBe(true)
 })
 it('rejects invalid optional minimum when parsing API policy', () => {
  const payload = {application_family:'boohtacord',catalog_revision:1,platform:'web',distribution:'browser',channel:'stable',arch:'any',state:'published',target:{release_id:'r5',release_order:5,version:'1',native_build:null,priority:'normal',summary:'test',release_notes_url:null,requirements:{supported_arches:['any']},action:{kind:'reload',url:null},minimum_release_order:6}}
  expect(() => parsePolicy(payload)).toThrow()
 })
})
