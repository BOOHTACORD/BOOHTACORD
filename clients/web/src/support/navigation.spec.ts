import { createSSRApp, h, ref } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { expect, it, vi } from 'vitest'
import { useWorkspaceNavigation } from '../workspace/workspace_navigation'
const mocks=vi.hoisted(()=>({open:vi.fn(),select:vi.fn(),support:vi.fn(),close:vi.fn()}))
vi.mock('../direct_message/direct_message_store',()=>({useDirectMessageStore:()=>({openSupport:mocks.support,open:mocks.open,close:mocks.close,directMessages:[]})}))
vi.mock('../direct_message/direct_message_candidate_store',()=>({useDirectMessageCandidateStore:()=>({})}))
async function navigation(){
 let nav!:ReturnType<typeof useWorkspaceNavigation>
 await renderToString(createSSRApp({setup(){nav=useWorkspaceNavigation('MEMBER',ref(null),{} as never,()=>{},mocks.select);return()=>h('div')}}))
 return nav
}
it('keeps the mobile drawer open when support is unavailable',async()=>{
 mocks.support.mockResolvedValue(null)
 const nav=await navigation();nav.navOpen.value=true;await nav.openSupport()
 expect(nav.navOpen.value).toBe(true);expect(nav.sidebarSection.value).toBe('messages')
})
it('does not steal a later channel selection when support resolves',async()=>{
 let release!:(id:string)=>void;mocks.support.mockImplementation(()=>new Promise<string>(resolve=>release=resolve));mocks.select.mockClear()
 const nav=await navigation();const pending=nav.openSupport();nav.selectChannel({id:'channel',kind:'TEXT'} as never);release('support-pair');await pending
 expect(mocks.select).not.toHaveBeenCalled();expect(nav.sidebarSection.value).toBe('channels')
})
