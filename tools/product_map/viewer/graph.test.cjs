const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

class Element {
  constructor() { this.children = []; this.textContent = ''; this.value = ''; }
  appendChild(child) { this.children.push(child); return child; }
  append(...children) { this.children.push(...children); }
  replaceChildren() { this.children = []; this.textContent = ''; }
  addEventListener() {}
  set innerHTML(_) { throw Error('unsafe HTML assignment'); }
}
function text(node) {
  return typeof node === 'string' ? node : node.textContent + node.children.map(text).join(' ');
}
test('feature graph displays explicit dependency edges as text', () => {
  const elements = Object.fromEntries(['rows', 'search', 'count', 'detail'].map(k => [k, new Element()]));
  const platforms = Object.fromEntries(['web', 'windows', 'macos', 'android', 'ios']
    .map(k => [k, { source_status: 'UNKNOWN', released: 'UNKNOWN', runtime: 'NOT_VERIFIED' }]));
  const data = [{ id: 'voice.a', title: 'A', description: 'A', platforms,
    components: [{ id: 'cmp.route', paths: ['route.go'] }, { id: 'cmp.service', paths: ['service.go'] }],
    component_edges: [{ from: 'cmp.route', to: 'cmp.service', type: 'depends_on' }] }];
  const document = { getElementById: id => elements[id], createElement: () => new Element(),
    createTextNode: value => value };
  const script = fs.readFileSync(path.join(__dirname, 'app.js'), 'utf8');
  vm.runInNewContext(script, { data, document, location: { hash: '#feature/voice.a' },
    window: { addEventListener() {} } });
  assert.match(text(elements.detail), /cmp\.route\s+→\s+cmp\.service/);
  assert.match(text(elements.detail), /зависит от/i);
});
