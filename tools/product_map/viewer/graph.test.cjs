const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

class Element {
  constructor() { this.children = []; this.textContent = ''; this.value = ''; this.checked = true; this.events = {}; }
  appendChild(child) { this.children.push(child); return child; }
  append(...children) { this.children.push(...children); }
  replaceChildren() { this.children = []; this.textContent = ''; }
  addEventListener(event, handler) { this.events[event] = handler; }
  set innerHTML(_) { throw Error('unsafe HTML assignment'); }
}
function elements() {
  const ids = ['rows', 'search', 'count', 'detail', 'header', 'platform', 'domain', 'status',
    'layer-source', 'layer-release', 'layer-runtime'];
  const values = Object.fromEntries(ids.map(k => [k, new Element()]));
  values.platform.value = values.domain.value = values.status.value = 'all';
  return values;
}
function script() {
  return ['filters.js', 'app.js'].map(file => fs.readFileSync(path.join(__dirname, file), 'utf8')).join('\n');
}
function text(node) {
  return typeof node === 'string' ? node : node.textContent + node.children.map(text).join(' ');
}
test('feature graph displays explicit dependency edges as text', () => {
  const nodes = elements();
  const platforms = Object.fromEntries(['web', 'windows', 'macos', 'android', 'ios']
    .map(k => [k, { source_status: 'UNKNOWN', released: 'UNKNOWN', runtime: 'NOT_VERIFIED' }]));
  const data = [{ id: 'voice.a', title: 'A', description: 'A', platforms,
    components: [{ id: 'cmp.route', paths: ['route.go'] }, { id: 'cmp.service', paths: ['service.go'] }],
    component_edges: [{ from: 'cmp.route', to: 'cmp.service', type: 'depends_on' }],
    depends_on: ['auth.session'] }];
  const document = { getElementById: id => nodes[id], createElement: () => new Element(),
    createTextNode: value => value };
  vm.runInNewContext(script(), { data, document, location: { hash: '#feature/voice.a' },
    window: { addEventListener() {} } });
  assert.match(text(nodes.detail), /cmp\.route\s+→\s+cmp\.service/);
  assert.match(text(nodes.detail), /зависит от/i);
  assert.match(text(nodes.detail), /auth\.session/);
});
test('matrix displays actual and target behavior revisions separately from release', () => {
  const nodes = elements();
  const item = { source_status: 'BEHIND', implemented_revision: 2, target_revision: 3,
    released: 'UNKNOWN', runtime: 'NOT_VERIFIED' };
  const platforms = Object.fromEntries(['web', 'windows', 'macos', 'android', 'ios'].map(k => [k, item]));
  const document = { getElementById: id => nodes[id], createElement: () => new Element(),
    createTextNode: value => value };
  vm.runInNewContext(script(), { data: [{ id: 'voice.a', description: 'A', platforms }], document,
    location: { hash: '' }, window: { addEventListener() {} } });
  assert.match(text(nodes.rows), /BEHIND.*r2.*r3/s);
  assert.match(text(nodes.rows), /Релиз: UNKNOWN/);
});
test('controls limit visible columns, rows and independent evidence layers', () => {
  const nodes = elements();
  const complete = {source_status: 'IN_SYNC', released: 'RELEASED', runtime: 'PASS'};
  const behind = {source_status: 'BEHIND', released: 'UNKNOWN', runtime: 'NOT_VERIFIED'};
  const common = {web: complete, windows: behind, macos: complete, android: complete, ios: complete};
  const document = {getElementById: id => nodes[id], createElement: () => new Element(), createTextNode: x => x};
  const data = [{id: 'voice.a', title: 'A', group: 'voice', description: 'A', platforms: common},
                {id: 'chat.b', title: 'B', group: 'chat', description: 'B', platforms: common}];
  vm.runInNewContext(script(), {data, document, location: {hash: ''}, window: {addEventListener() {}}});
  nodes.platform.value = 'windows'; nodes.domain.value = 'voice'; nodes.status.value = 'behind';
  nodes['layer-source'].checked = false; nodes['layer-runtime'].checked = false;
  nodes.status.events.change();
  assert.match(text(nodes.header), /Windows/);
  assert.doesNotMatch(text(nodes.header), /Web/);
  assert.match(text(nodes.rows), /voice\.a/);
  assert.doesNotMatch(text(nodes.rows), /chat\.b|Код:|Runtime:/);
  assert.match(text(nodes.rows), /Релиз: UNKNOWN/);
});
