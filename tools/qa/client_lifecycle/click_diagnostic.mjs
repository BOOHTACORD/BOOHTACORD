// Publish only a fixed classification; the exception itself stays in the private log.
export function clickFailureStage(error) {
  const message = String(error)
  if (message.includes('intercepts pointer events')) return 'settings-cancel-pointer-blocked'
  if (message.includes('not enabled')) return 'settings-cancel-disabled'
  if (message.includes('strict mode violation')) return 'settings-cancel-ambiguous'
  if (message.includes('outside of the viewport')) return 'settings-cancel-outside'
  return 'settings-cancel-other'
}
