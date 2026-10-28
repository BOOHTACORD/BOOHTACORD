interface Refreshable { error: string | null; refresh(): Promise<void> }
interface TextHistory extends Refreshable {
  channelId: string | null
  applyDeletedHint?(channelId: string, messageId: string): void
  refreshMessages?(ids: string[]): Promise<unknown>
}
interface DirectHistory {
  directMessageId: string | null
  error: string | null
  refreshNavigation(): Promise<void>
  refreshHistory(): Promise<void>
  applyDeletedHint?(directMessageId: string, messageId: string): void
  refreshMessages?(ids: string[]): Promise<unknown>
}
export interface WorkspaceRealtimeStores {
  topology: Refreshable
  messages: TextHistory
  directMessages: DirectHistory
}
