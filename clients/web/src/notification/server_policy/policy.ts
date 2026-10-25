export type PolicyInput = {
  ttl_ms?: number;
  version: number;
  kind: string;
  actor_id: string;
  recipient_id: string;
  mentioned: boolean;
  read: boolean;
  deleted: boolean;
  archived: boolean;
  revoked: boolean;
  operator_available: boolean;
  account_enabled: boolean;
  device_consent: boolean;
  mode: string;
  paused_until_ms: number;
  now_ms: number;
  occurred_at_ms: number;
};

export interface PolicyResult { eligible: boolean; reason: string }

const MAX_EPOCH_MS = Number.MAX_SAFE_INTEGER;

export function evaluateNotificationPolicy(input: PolicyInput): PolicyResult {
  if (input.version !== 1) return { eligible: false, reason: "unsupported_version" };
  if (!input.actor_id || !input.recipient_id) return { eligible: false, reason: "invalid" };
  const ttl = input.ttl_ms ?? 0;
  if (!Number.isSafeInteger(ttl) || (ttl !== 0 && (ttl < 60000 || ttl > 86400000))) return { eligible: false, reason: 'invalid' };
  if (input.mode !== "all" && input.mode !== "mentions" && input.mode !== "none") return { eligible: false, reason: "invalid" };
  const ts = [input.paused_until_ms, input.now_ms, input.occurred_at_ms];
  if (!ts.every(Number.isSafeInteger) || ts.some(v => v < 0 || v > MAX_EPOCH_MS) || input.occurred_at_ms > input.now_ms) return { eligible: false, reason: "invalid" };
  if (!input.operator_available) return { eligible: false, reason: "unavailable" };
  if (!input.account_enabled || !input.device_consent) return { eligible: false, reason: "no_consent" };
  if (input.actor_id === input.recipient_id) return { eligible: false, reason: "self" };
  if (input.kind !== "DM" && input.kind !== "TEXT") return { eligible: false, reason: "event_kind" };
  if (input.deleted) return { eligible: false, reason: "deleted" };
  if (input.archived) return { eligible: false, reason: "archived" };
  if (input.revoked) return { eligible: false, reason: "revoked" };
  if (input.read) return { eligible: false, reason: "read" };
  if (input.now_ms - input.occurred_at_ms >= (ttl || 3600000)) return { eligible: false, reason: "expired" };
  if (input.now_ms < input.paused_until_ms) return { eligible: false, reason: "paused" };
  if (input.mode === "none") return { eligible: false, reason: "muted" };
  if (input.mode === "mentions" && !input.mentioned) return { eligible: false, reason: "not_mentioned" };
  return { eligible: true, reason: "eligible" };
}
