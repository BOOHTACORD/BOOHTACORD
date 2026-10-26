/* Transactional worker state. Never stores message content. */
((global) => {
  'use strict';
  let connection;
  function open() {
    if (!connection) connection = new Promise((resolve, reject) => {
      const request = indexedDB.open('boohtacord-notifications-v1', 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore('state');
        request.result.createObjectStore('seen', { keyPath: 'key' }).createIndex('expiry', 'expiry');
      };
      request.onsuccess = () => { request.result.onversionchange = () => { request.result.close(); connection = null; }; resolve(request.result); };
      request.onerror = () => { connection = null; reject(new Error('Notification storage unavailable')); };
    });
    return connection;
  }
  async function transaction(stores, mode, action) {
    const db = await open();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(stores, mode); let result;
      tx.oncomplete = () => resolve(result);
      tx.onerror = tx.onabort = () => reject(new Error('Notification storage transaction failed'));
      action(tx, (value) => { result = value; });
    });
  }
  global.notificationState = {
    read() {
      return transaction(['state'], 'readonly', (tx, done) => {
        const r = tx.objectStore('state').get('current'); r.onsuccess = () => done(r.result || null);
      });
    },
    set(expectedEpoch, state) {
      if (!Number.isSafeInteger(expectedEpoch) || expectedEpoch < 0 || typeof state?.scope !== 'string' || state.scope.length > 1024 || typeof state.active !== 'boolean') return Promise.resolve({ ok: false });
      return transaction(['state'], 'readwrite', (tx, done) => {
        const store = tx.objectStore('state'); const r = store.get('current');
        r.onsuccess = () => {
          if ((r.result?.epoch || 0) !== expectedEpoch) { done({ ok: false }); return; }
          if (state.active && (r.result?.clearing || r.result?.pending_revoke)) { done({ ok: false }); return; }
          const record = { epoch: expectedEpoch + 1, scope: state.scope, binding: state.binding, generation: state.generation, active: state.active, clearing: !!state.clearing, pending_revoke: !!state.pending_revoke, address_hash: typeof state.address_hash === 'string' ? state.address_hash.slice(0, 64) : '', refresh_requested: !!state.refresh_requested };
          store.put(record, 'current'); done({ ok: true, record });
        };
      });
    },
    claim(scope, ref, expiry, generation) {
      return transaction(['state', 'seen'], 'readwrite', (tx, done) => {
        const current = tx.objectStore('state').get('current');
        current.onsuccess = () => {
          if (!current.result?.active || current.result.scope !== scope || current.result.generation !== generation) { done({ ok: false }); return; }
          const store = tx.objectStore('seen'); const all = store.index('expiry').getAll();
          all.onsuccess = () => {
            const key = `${scope}\0${ref}`; const now = Date.now(); let duplicate = false;
            const alive = all.result.filter((item) => { if (item.expiry <= now) { store.delete(item.key); return false; } return true; });
            for (const item of alive) if (item.key === key) duplicate = true;
            if (!duplicate) {
              while (alive.length >= 512) store.delete(alive.shift().key);
              store.put({ key, scope, expiry });
            }
            done({ ok: true, duplicate });
          };
        };
      });
    },
    clearScope(scope, expectedEpoch) {
      return transaction(['state', 'seen'], 'readwrite', (tx, done) => {
        const store = tx.objectStore('state'); const r = store.get('current');
        r.onsuccess = () => {
          if (!r.result || r.result.scope !== scope || r.result.epoch !== expectedEpoch) { done({ ok: false }); return; }
          store.put({ epoch: expectedEpoch + 1, scope: '', active: false, binding: r.result.binding, pending_revoke: true }, 'current');
          const seen = tx.objectStore('seen'); const cursor = seen.openCursor();
          cursor.onsuccess = () => { const row = cursor.result; if (!row) return; if (row.value.scope === scope) row.delete(); row.continue(); };
          done({ ok: true, binding: r.result.binding });
        };
      });
    },
  };
})(self);
