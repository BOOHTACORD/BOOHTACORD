import { expect, it } from 'vitest'
import { LegacySoundReview } from './legacy'
it('requires an explicit choice per account without changing unowned flags', () => {
  const values = new Map([['voice-screen-start-sound:v1','off']])
  const storage = { getItem:(key:string) => values.get(key) ?? null, setItem:(key:string,value:string) => {values.set(key,value)}, removeItem:(key:string) => {values.delete(key)} }
  const review = new LegacySoundReview(storage)
  review.select('a'); expect(review.blocked.value).toBe(true); review.acknowledge()
  review.select('b'); expect(review.blocked.value).toBe(true)
  review.select('a'); expect(review.blocked.value).toBe(false)
  expect(values.get('voice-screen-start-sound:v1')).toBe('off')
})
