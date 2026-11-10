const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, 'detail.js'), 'utf8'), context);

test('source links are limited to the repository and explicit revision', () => {
  const sha = 'a'.repeat(40);
  assert.equal(context.sourceURL('backend/internal/voice/service.go', sha),
    'https://github.com/BOOHTACORD/BOOHTACORD/blob/' + sha + '/backend/internal/voice/service.go');
  assert.match(context.sourceURL('clients/web/src/a.ts', null), /\/blob\/master\//);
  for (const path of ['../secret', '/absolute', 'https://evil.test/x', 'a\\b', 'a/../secret']) {
    assert.equal(context.sourceURL(path, sha), null);
  }
  assert.equal(context.sourceURL('a.ts', 'master'), null);
});
test('issue links reject invalid identifiers and never point to another host', () => {
  assert.equal(context.issueURL(688), 'https://github.com/BOOHTACORD/BOOHTACORD/issues/688');
  for (const value of [0, -1, 1.5, '688', true, Number.MAX_SAFE_INTEGER + 1]) {
    assert.equal(context.issueURL(value), null);
  }
});
