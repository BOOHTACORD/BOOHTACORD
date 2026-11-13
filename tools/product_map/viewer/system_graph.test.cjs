const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

class Element {
  constructor(tag) { this.tag = tag; this.children = []; this.attributes = {}; this.textContent = '' }
  setAttribute(key, value) { this.attributes[key] = value }
  appendChild(child) { this.children.push(child); return child }
  replaceChildren() { this.children = []; this.textContent = '' }
  set innerHTML(_) { throw Error('unsafe HTML assignment') }
}

test('system graph renders each node once and exposes safe source links', () => {
  const document = { createElementNS: (_, tag) => new Element(tag), createElement: tag => new Element(tag) }
  const graph = { nodes: [
    { id: 'sys.flutter.shared', label: '<script>unsafe</script>', kind: 'shared_component', path: 'clients/flutter/lib/main.dart', x: 400, y: 100 },
    { id: 'sys.android', label: 'Android', kind: 'platform_adapter', path: 'clients/flutter/android/Main.kt', x: 20, y: 100 },
  ], edges: [{ from: 'sys.android', to: 'sys.flutter.shared', type: 'runs' }] }
  const svg = new Element('svg'), links = new Element('ul'), edges = new Element('ul')
  const code = fs.readFileSync(path.join(__dirname, 'system_graph.js'), 'utf8')
  vm.runInNewContext(code + '\nrenderSystemGraph(graph, svg, links, edges)', {
    document, graph, svg, links, edges, sourceURL: path => 'https://github.com/BOOHTACORD/BOOHTACORD/blob/master/' + path,
  })
  assert.equal(svg.children.filter(item => item.tag === 'g').length, 2)
  assert.equal(svg.children.filter(item => item.tag === 'line').length, 1)
  assert.equal(svg.children.find(item => item.tag === 'line').attributes.x2, '400')
  assert.equal(links.children.length, 2)
  assert.equal(edges.children.length, 1)
  assert.match(edges.children[0].textContent, /Android.*использует.*unsafe/)
  assert.equal(links.children[0].children[0].textContent, '<script>unsafe</script>')
  assert.match(links.children[0].children[0].href, /^https:\/\/github\.com\/BOOHTACORD\/BOOHTACORD\/blob\/master\//)
})
