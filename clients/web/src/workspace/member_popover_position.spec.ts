import { describe, expect, it } from 'vitest'
import { placeMemberPopover, type Rect } from './member_popover_position'
const viewport = { x:0, y:64, width:1440, height:836 }
const overlaps = (a:Rect,b:Rect) => a.x < b.x+b.width && a.x+a.width > b.x && a.y < b.y+b.height && a.y+a.height > b.y
function bounded(result:Rect, box:Rect) {
  expect(result.x).toBeGreaterThanOrEqual(box.x+8)
  expect(result.y).toBeGreaterThanOrEqual(box.y+8)
  expect(result.x+result.width).toBeLessThanOrEqual(box.x+box.width-8)
  expect(result.y+result.height).toBeLessThanOrEqual(box.y+box.height-8)
}
describe('member profile collision placement', () => {
  it('anchors beside the roster and flips vertically for the last member', () => {
    const anchor={x:1190,y:820,width:226,height:44}
    const result=placeMemberPopover(viewport,anchor,{width:304,height:280},[])
    bounded(result,viewport)
    expect(result.x+result.width).toBeLessThanOrEqual(anchor.x-8)
  })
  it.each([320,390,1024,1440])('keeps a long-name profile clear of composer, dock and mini-player at %ipx', width => {
    const box={x:0,y:56,width,height:788}, anchor={x:width-210,y:600,width:190,height:44}
    const obstacles=[{x:0,y:730,width,height:114},{x:width-240,y:560,width:240,height:160}]
    const result=placeMemberPopover(box,anchor,{width:304,height:360},obstacles)
    bounded(result,box)
    expect(obstacles.some(o=>overlaps(result,o))).toBe(false)
  })
  it('shrinks the scrollable card instead of moving controls behind the keyboard/composer', () => {
    const box={x:0,y:60,width:320,height:280}, obstacle={x:0,y:260,width:320,height:80}
    const result=placeMemberPopover(box,{x:90,y:100,width:210,height:44},{width:304,height:500},[obstacle])
    bounded(result,box)
    expect(result.height).toBeLessThan(200)
    expect(overlaps(result,obstacle)).toBe(false)
  })
  it('handles visual viewport offsets and fractional geometry', () => {
    const box={x:12.5,y:30.5,width:390,height:500}
    bounded(placeMemberPopover(box,{x:300,y:480,width:80,height:44},{width:304,height:270},[]),box)
  })
})
