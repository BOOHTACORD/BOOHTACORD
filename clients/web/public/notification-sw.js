importScripts('/notification-state.js');
function notificationUTC(value) {
  if (typeof value !== 'string') return NaN
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+]00:00)$/.exec(value)
  const time = new Date(value)
  if (!match || !Number.isFinite(time.getTime()) || time.getUTCFullYear() < 1) return NaN
  const parts = [time.getUTCFullYear(), time.getUTCMonth() + 1, time.getUTCDate(), time.getUTCHours(), time.getUTCMinutes(), time.getUTCSeconds()]
  return parts.every((part, i) => part === Number(match[i + 1])) ? time.getTime() : NaN
}

const opaque = /^[A-Za-z0-9_-]{16,128}$/;
const titles = { direct_message: 'Новое личное сообщение', mention: 'Новое упоминание', activity: 'Новая активность' };
function valid(p) {
  if (!p || Object.keys(p).sort().join(',') !== 'binding_ref,expires_at,generation,group_ref,notification_ref,template,version') return false;
  if (p.version !== 1 || !Number.isSafeInteger(p.generation) || p.generation < 1 || p.generation > 1e9) return false;
  if (![p.binding_ref, p.notification_ref, p.group_ref].every((v) => typeof v === 'string' && opaque.test(v))) return false;
  if (!Object.hasOwn(titles, p.template) || typeof p.expires_at !== 'string' || !/(Z|[+]00:00)$/.test(p.expires_at)) return false;
  const expiry = notificationUTC(p.expires_at); return expiry > Date.now() && expiry <= Date.now() + 86400000;
}
async function present(payload) {
  let options = { icon: '/favicon.png', data: {}, tag: 'boohtacord-generic', renotify: false };
  let title = 'Уведомление BOOHTACORD';
  try {
    if (valid(payload)) {
      const state = await self.notificationState.read();
      if (state?.active && state.binding === payload.binding_ref && state.generation === payload.generation) {
        const claim = await self.notificationState.claim(state.scope, payload.notification_ref, Date.parse(payload.expires_at), payload.generation);
        if (claim.ok) {
          title = titles[payload.template];
          options = { icon: '/favicon.png', tag: `boohtacord:${payload.group_ref}`, renotify: !claim.duplicate, silent: claim.duplicate,
            data: { ref: payload.notification_ref, generation: payload.generation, binding_ref: payload.binding_ref } };
        }
      }
    }
  } catch { /* Storage failure still requires a neutral visible path. */ }
  await self.registration.showNotification(title, options);
}
self.addEventListener('push', (event) => {
  let payload; try { payload = event.data?.json(); } catch { payload = null; }
  event.waitUntil(present(payload));
});
self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil((async () => {
    const state = await self.notificationState.read();
    if (state?.active) await self.notificationState.set(state.epoch, { ...state, refresh_requested: true });
    // Authenticated pages rotate only an existing consented issuing profile.
    // A worker never borrows ambient cookies to enroll a different account.
  })());
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const data = event.notification.data || {};
    const route = typeof data.ref === 'string' && opaque.test(data.ref) && Number.isSafeInteger(data.generation) && data.generation > 0;
    const message = route ? { type: 'notification.open', ref: data.ref, generation: data.generation } : { type: 'notification.open' };
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) if (new URL(client.url).origin === location.origin) {
      await client.focus(); client.postMessage(message); return;
    }
    const fragment = route ? '#notification=' + encodeURIComponent(JSON.stringify({ ref: data.ref, generation: data.generation })) : '';
    await self.clients.openWindow(location.origin + '/' + fragment);
  })());
});
self.addEventListener('message', (event) => {
  event.waitUntil((async () => {
    const source = event.source; const port = event.ports?.[0];
    if (!source || source.type !== 'window' || new URL(source.url).origin !== location.origin || !port) return;
    const input = event.data || {}; let reply = { ok: false };
    try {
      if (input.type === 'READ') reply = { ok: true, record: await self.notificationState.read() };
      if (input.type === 'SET') reply = await self.notificationState.set(input.expectedEpoch, input.state);
      if (input.type === 'CLEAR') {
        reply = await self.notificationState.clearScope(input.scope, input.expectedEpoch);
        if (reply.ok) {
          for (const card of await self.registration.getNotifications()) if (card.data?.binding_ref === reply.binding) card.close();
          reply = await reconcile();
        }
      }
      if (input.type === 'RECONCILE') reply = await reconcile();
    } catch { reply = { ok: false }; }
    port.postMessage(reply);
  })());
});
async function reconcile() {
  const current = await self.notificationState.read();
  if (!current?.pending_revoke) return { ok: true };
  const fenced = await self.notificationState.set(current.epoch, { ...current, active: false, clearing: true });
  if (!fenced.ok) return { ok: false };
  let complete = false;
  try {
    const attempt = (async () => { const sub = await self.registration.pushManager.getSubscription(); return !sub || await sub.unsubscribe(); })();
    complete = await Promise.race([attempt, new Promise(resolve => setTimeout(() => resolve(false), 2500))]);
  } catch { complete = false; }
  const result = await self.notificationState.set(fenced.record.epoch, { scope: '', active: false, pending_revoke: !complete, clearing: false, binding: current.binding });
  return { ok: result.ok && complete };
}
