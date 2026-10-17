import type { ObjectDirective } from 'vue'

let nextId = 0
interface Hint { update: (text?: string) => void; dismiss: () => void; dispose: () => void }
const hints = new WeakMap<HTMLElement, Hint>()
let activeHint: (() => void) | null = null

function install(button: HTMLElement, text?: string): Hint {
  let explicitText = text
  let tooltip: HTMLDivElement | null = null
  let visibilityObserver: MutationObserver | null = null
  let timer: ReturnType<typeof setTimeout> | undefined
  let hovered = false, focus = false, dismissed = false
  const id = `gc-action-hint-${++nextId}`
  const label = () => explicitText?.trim() || button.getAttribute('aria-label')?.trim() || ''
  function clearTimer() { if (timer !== undefined) clearTimeout(timer); timer = undefined }
  function hide() {
    clearTimer(); visibilityObserver?.disconnect(); visibilityObserver = null
    tooltip?.remove(); tooltip = null
    if (activeHint === hide) activeHint = null
    const rest = (button.getAttribute('aria-describedby') ?? '').split(/\s+/).filter(value => value && value !== id)
    if (rest.length) button.setAttribute('aria-describedby', rest.join(' ')); else button.removeAttribute('aria-describedby')
    document.removeEventListener('keydown', escape, true)
    window.removeEventListener('resize', reflow)
    window.removeEventListener('scroll', reflow, true)
  }
  function position() {
    if (!tooltip) return
    // Even translateY(0) on the existing dialog creates a containing block for
    // fixed children. Measure its origin instead of treating local CSS offsets
    // as viewport coordinates; keep the hint inside a clipping modal as well.
    tooltip.style.left = '0px'; tooltip.style.top = '0px'
    const rect = button.getBoundingClientRect(), origin = tooltip.getBoundingClientRect()
    const modal = button.closest('dialog[open]')?.getBoundingClientRect()
    const left = Math.max(8, (modal?.left ?? 0) + 8), right = Math.min(innerWidth - 8, (modal?.right ?? innerWidth) - 8)
    const top = Math.max(8, (modal?.top ?? 0) + 8), bottom = Math.min(innerHeight - 8, (modal?.bottom ?? innerHeight) - 8)
    const x = Math.max(left, Math.min(rect.left + (rect.width - origin.width) / 2, right - origin.width))
    const below = rect.bottom + 8
    const y = Math.max(top, Math.min(below + origin.height <= bottom ? below : rect.top - origin.height - 8, bottom - origin.height))
    tooltip.style.left = `${x - origin.left}px`; tooltip.style.top = `${y - origin.top}px`
  }
  function visible() { return button.isConnected && button.getClientRects().length > 0 && getComputedStyle(button).visibility === 'visible' && !button.closest('[inert]') }
  function reflow() {
    const rect = button.getBoundingClientRect()
    if (focus && rect.bottom > 0 && rect.top < innerHeight && rect.right > 0 && rect.left < innerWidth) position()
    else hide()
  }
  function show() {
    clearTimer()
    if (!visible()) { hide(); return }
    if (dismissed || !label() || button.matches(':disabled') || !button.isConnected) return
    if (activeHint !== hide) activeHint?.()
    activeHint = hide
    tooltip ??= document.createElement('div')
    tooltip.id = id; tooltip.className = 'gc-action-hint'; tooltip.setAttribute('role', 'tooltip'); tooltip.textContent = label()
    tooltip.onpointerenter = () => { hovered = true; clearTimer() }
    tooltip.onpointerleave = () => { hovered = false; scheduleHide() }
    // Native modal dialogs live in the top layer; a body sibling is inert and
    // painted behind their backdrop, regardless of its z-index.
    const host = button.closest('dialog[open]') ?? document.body
    host.append(tooltip)
    // Closing a drawer may hide its row without unmounting or changing props.
    // Observe only this trigger's ancestors while a hint exists; never leave a
    // body tooltip intercepting the header after its source becomes hidden.
    if (!visibilityObserver) {
      visibilityObserver = new MutationObserver(() => { if (!visible()) hide() })
      for (let node: HTMLElement | null = button; node; node = node.parentElement) {
        visibilityObserver.observe(node, { attributes: true, attributeFilter: ['class','style','hidden','inert','open'] })
      }
    }
    position()
    const descriptions = new Set((button.getAttribute('aria-describedby') ?? '').split(/\s+/).filter(Boolean))
    descriptions.add(id); button.setAttribute('aria-describedby', [...descriptions].join(' '))
    document.addEventListener('keydown', escape, true)
    window.addEventListener('resize', reflow)
    window.addEventListener('scroll', reflow, true)
  }
  function scheduleHide() { clearTimer(); timer = setTimeout(() => { if (!hovered && !focus) hide() }, 150) }
  function escape(event: KeyboardEvent) { if (event.key === 'Escape') { dismissed = true; hide() } }
  function enter(event: PointerEvent) { if (event.pointerType === 'touch') return; hovered = true; dismissed = false; show() }
  function leave() { hovered = false; if (!focus) dismissed = false; scheduleHide() }
  function onFocus() { focus = button.matches(':focus-visible'); if (focus) show() }
  function onBlur() { focus = false; dismissed = false; if (!hovered) hide() }
  function dismiss() { if (hovered) dismissed = true; hovered = false; hide() }
  button.addEventListener('pointerenter', enter); button.addEventListener('pointerleave', leave)
  button.addEventListener('focus', onFocus); button.addEventListener('blur', onBlur)
  // The managed hint replaces the native mouse-only title balloon. Its text
  // always follows the existing accessible action name, including toggles.
  function update(text?: string) { explicitText = text; button.removeAttribute('title'); if (tooltip) { if (button.matches(':disabled')) hide(); else show() } }
  update(text)
  return { update, dispose() {
    hide(); button.removeEventListener('pointerenter', enter); button.removeEventListener('pointerleave', leave)
    button.removeEventListener('focus', onFocus); button.removeEventListener('blur', onBlur)
  }, dismiss }
}

export function dismissActionHint(button: HTMLElement | null | undefined): void {
  if (button) hints.get(button)?.dismiss()
}

export const vActionHint: ObjectDirective<HTMLElement, string | undefined> = {
  mounted(button, binding) { hints.set(button, install(button, binding.value)) },
  updated(button, binding) { hints.get(button)?.update(binding.value) },
  unmounted(button) { hints.get(button)?.dispose(); hints.delete(button) },
}
