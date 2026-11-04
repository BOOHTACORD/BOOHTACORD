import type { Directive } from 'vue'

const originalTabStops = new WeakMap<HTMLElement, Map<HTMLElement, string | null>>()
function bindTabStops(element: HTMLElement, detached: boolean): void {
  const saved = originalTabStops.get(element) ?? new Map<HTMLElement, string | null>()
  for (const [target, value] of saved) if (!detached || !element.contains(target)) {
    if (value === null) target.removeAttribute('tabindex')
    else target.setAttribute('tabindex', value)
    saved.delete(target)
  }
  if (!detached) { originalTabStops.delete(element); return }
  for (const target of element.querySelectorAll<HTMLElement>('button, [href], input, select, textarea, [tabindex], summary')) {
    if (!saved.has(target)) saved.set(target, target.getAttribute('tabindex'))
    target.setAttribute('tabindex', '-1')
  }
  originalTabStops.set(element, saved)
}
export const vRetainedEditingPin: Directive<HTMLElement, boolean> = {
  mounted: (element, binding) => bindTabStops(element, binding.value),
  updated: (element, binding) => bindTabStops(element, binding.value),
  beforeUnmount: (element) => bindTabStops(element, false),
}
