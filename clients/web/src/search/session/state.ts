import {defineStore} from 'pinia'
import {ref} from 'vue'
import type {AttachmentFilter} from '../filters/state'
export interface SearchSession {
 query:string
 activeQuery:string
 scope:'all'|'current'
 authorId:string
 attachment:AttachmentFilter
 dateFrom:string
 dateTo:string
 submitted:boolean
 scrollTop:number
}
/** Memory belongs to the authenticated Pinia store and is discarded at logout. */
export const useSearchSessions=defineStore('search-sessions',()=>{
 const sessions=ref<Record<string,SearchSession>>({})
 function save(origin:string,session:SearchSession):void {sessions.value[origin]={...session}}
 function restore(origin:string):SearchSession|null {const saved=sessions.value[origin];return saved?{...saved}:null}
 return {sessions,save,restore}
})
