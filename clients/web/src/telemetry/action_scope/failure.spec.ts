import { expect,it } from 'vitest'
import { failureOutcome } from './failure'
it('distinguishes deadline timeouts from explicit cancellation without exporting error text',()=>{
 expect(failureOutcome(new DOMException('private deadline','TimeoutError'))).toEqual({outcome:'timeout',reason:'deadline'})
 expect(failureOutcome(new DOMException('private abort','AbortError'))).toEqual({outcome:'cancelled',reason:'disposed'})
})
