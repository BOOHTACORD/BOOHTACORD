import { notificationUTC } from '../remote_push/utc'
export type Mode = "all" | "mentions" | "none";
export interface Preference { mode: Mode; paused_until: string | null }
export interface Override extends Preference { kind: "CHANNEL" | "DIRECT_MESSAGE"; id: string }
export interface Settings { version: 1; revision: number; enabled: boolean; dm: Preference; text: Preference; overrides: Override[]; imported: boolean }
export interface Snapshot { capability: { version: 1; available: boolean; device_transport: string }; settings: Settings }
export class PreferenceError extends Error { status: number; constructor(message: string, status: number) { super(message); this.name = "PreferenceError"; this.status = status } }
const MODES: readonly Mode[] = ["all", "mentions", "none"];
const KINDS: readonly Override["kind"][] = ["CHANNEL", "DIRECT_MESSAGE"];
function isMode(v: unknown): v is Mode { return typeof v === "string" && (MODES as readonly string[]).includes(v) }
function parsePref(v: unknown): Preference {
  if (typeof v !== "object" || v === null) throw new Error("invalid preference");
  const o = v as Record<string, unknown>;
  if (!isMode(o.mode)) throw new Error("invalid mode");
  const p = o.paused_until;
  if (p === null || p === undefined) return { mode: o.mode, paused_until: null };
  if (typeof p !== 'string' || !/(Z|[+]00:00)$/.test(p) || !Number.isFinite(notificationUTC(p))) throw new Error('invalid pause');
  return { mode: o.mode, paused_until: p };
}
function parseOverride(v: unknown): Override {
  if (typeof v !== "object" || v === null) throw new Error("invalid override");
  const o = v as Record<string, unknown>;
  const kind = o.kind as Override["kind"];
  if (!KINDS.includes(kind)) throw new Error("invalid override kind");
  if (typeof o.id !== "string") throw new Error("invalid override id");
  return { ...parsePref(o), kind, id: o.id };
}
function parseSettings(v: unknown): Settings {
  if (typeof v !== "object" || v === null) throw new Error("invalid settings");
  const s = v as Record<string, unknown>;
  if (s.version !== 1) throw new Error("unsupported version");
  const r = s.revision;
  if (typeof r !== "number" || !Number.isSafeInteger(r) || r < 0) throw new Error("invalid revision");
  if (typeof s.enabled !== "boolean" || typeof s.imported !== "boolean") throw new Error("invalid flags");
  const overrides = s.overrides;
  if (!Array.isArray(overrides) || overrides.length > 100) throw new Error("invalid overrides");
  return { version: 1, revision: r, enabled: s.enabled, dm: parsePref(s.dm), text: parsePref(s.text), overrides: (overrides as unknown[]).map(parseOverride), imported: s.imported };
}
function parseSnapshot(v: unknown): Snapshot {
  if (typeof v !== "object" || v === null) throw new Error("invalid snapshot");
  const o = v as Record<string, unknown>;
  const cap = o.capability as Record<string, unknown> | undefined;
  if (!cap || cap.version !== 1 || typeof cap.available !== "boolean" || typeof cap.device_transport !== "string") throw new Error("invalid capability");
  return { capability: { version: 1, available: cap.available, device_transport: cap.device_transport }, settings: parseSettings(o.settings) };
}
export function createNotificationPreferencesClient(request: typeof fetch = globalThis.fetch.bind(globalThis), account?: string) {
  let unsupported = false;
  async function load(): Promise<Snapshot | null> {
    if (unsupported) return null;
    const res = await request("/api/v1/notification-preferences", { method: "GET", credentials: "same-origin", headers: account ? { 'X-Notification-Account': account } : {} });
    if (res.status === 404 || res.status === 405) { unsupported = true; return null }
    if (!res.ok) throw new PreferenceError("load failed", res.status);
    return parseSnapshot(await res.json());
  }
  async function put(method: "PUT" | "POST", path: string, body: Record<string, unknown>): Promise<Snapshot> {
    if (unsupported) throw new PreferenceError('Server has no notification preferences API', 503);
    const res = await request(path, { method, credentials: "same-origin", headers: { "Content-Type": "application/json", ...(account ? { 'X-Notification-Account': account } : {}) }, body: JSON.stringify(body) });
    if (!res.ok) throw new PreferenceError("mutation failed", res.status);
    return parseSnapshot(await res.json());
  }
  function save(settings: Settings, expected_revision: number): Promise<Snapshot> { return put("PUT", "/api/v1/notification-preferences", { settings, expected_revision }) }
  function importExplicit(overrides: Override[], local_disabled: boolean, expected_revision: number): Promise<Snapshot> {
    return put("POST", "/api/v1/notification-preferences/import", { overrides, local_disabled, expected_revision });
  }
  return { load, save, importExplicit };
}
