export interface Rect { x: number; y: number; width: number; height: number }
const gap = 8
const right = (r: Rect) => r.x + r.width
const bottom = (r: Rect) => r.y + r.height
const intersects = (a: Rect, b: Rect) => a.x < right(b) && right(a) > b.x && a.y < bottom(b) && bottom(a) > b.y
const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(value, max))

// Split available space around protected controls. Prefer the complete card
// beside its trigger; a short visual viewport gets an internally scrolling card.
export function placeMemberPopover(viewport: Rect, anchor: Rect, size: Pick<Rect, 'width' | 'height'>, obstacles: Rect[]): Rect {
  let spaces: Rect[] = [{ x: viewport.x + gap, y: viewport.y + gap, width: Math.max(0, viewport.width - 2 * gap), height: Math.max(0, viewport.height - 2 * gap) }]
  for (const obstacle of obstacles.filter(r => r.width > 0 && r.height > 0)) {
    const blocked = { x: obstacle.x - gap, y: obstacle.y - gap, width: obstacle.width + 2 * gap, height: obstacle.height + 2 * gap }
    spaces = spaces.flatMap(space => !intersects(space, blocked) ? [space] : [
      { ...space, width: blocked.x - space.x },
      { ...space, x: right(blocked), width: right(space) - right(blocked) },
      { ...space, height: blocked.y - space.y },
      { ...space, y: bottom(blocked), height: bottom(space) - bottom(blocked) },
    ].filter(r => r.width > 0 && r.height > 0))
  }
  const candidates = spaces.map(space => {
    const width = Math.min(size.width, space.width), height = Math.min(size.height, space.height)
    const x = clamp(anchor.x - gap - width, space.x, right(space) - width)
    const y = clamp(anchor.y, space.y, bottom(space) - height)
    return { x, y, width, height }
  })
  candidates.sort((a, b) => {
    // Readable width first, then avoid vertical clipping, then stay at the anchor.
    const fit = (r: Rect) => Math.min(1, r.width / size.width) * 2 + Math.min(1, r.height / size.height)
    const distance = (r: Rect) => Math.abs(right(r) + gap - anchor.x) + Math.abs(r.y - anchor.y)
    return fit(b) - fit(a) || distance(a) - distance(b)
  })
  // A fully covered viewport has no free area: hide the card until layout frees
  // space, rather than paint controls on top of the composer.
  return candidates[0] ?? { x: viewport.x, y: viewport.y, width: 0, height: 0 }
}
