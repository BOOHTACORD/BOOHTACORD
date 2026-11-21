const activityEvents = ['pointerdown', 'pointermove', 'keydown', 'touchstart', 'wheel'] as const

export function startAppInteraction(target: EventTarget, report: () => void): () => void {
  activityEvents.forEach(event => target.addEventListener(event, report, { passive: true }))
  return () => activityEvents.forEach(event => target.removeEventListener(event, report))
}
