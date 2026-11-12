function renderSystemGraph(graph, svg, links, edgeList) {
  const ns = 'http://www.w3.org/2000/svg';
  const make = name => document.createElementNS(ns, name);
  svg.replaceChildren(); links.replaceChildren(); edgeList.replaceChildren();
  const relations = { runs: 'использует', routes: 'направляет к', calls: 'обращается к',
    depends_on: 'зависит от', media: 'передаёт медиа через', verified_by: 'имеет тест',
    implements: 'реализует', shared_by: 'используется', emits: 'отправляет', consumes: 'принимает' };
  const defs = make('defs'), marker = make('marker'), arrow = make('path');
  for (const [key, value] of Object.entries({ id: 'system-arrow', viewBox: '0 0 10 10',
    refX: '9', refY: '5', markerWidth: '6', markerHeight: '6', orient: 'auto-start-reverse' })) marker.setAttribute(key, value);
  arrow.setAttribute('d', 'M 0 0 L 10 5 L 0 10 z');
  marker.appendChild(arrow); defs.appendChild(marker); svg.appendChild(defs);
  const nodes = new Map(graph.nodes.map(node => [node.id, node]));
  for (const edge of graph.edges) {
    const from = nodes.get(edge.from), to = nodes.get(edge.to);
    if (!from || !to) continue;
    const item = document.createElement('li');
    item.textContent = from.label + ' ' + (relations[edge.type] || edge.type) + ' ' + to.label;
    edgeList.appendChild(item);
    const dx = to.x - from.x, dy = to.y - from.y;
    const margin = Math.min(dx ? 90 / Math.abs(dx) : Infinity, dy ? 28 / Math.abs(dy) : Infinity);
    const line = make('line');
    for (const [key, value] of Object.entries({ x1: from.x + 90 + dx * margin, y1: from.y + 28 + dy * margin,
      x2: to.x + 90 - dx * margin, y2: to.y + 28 - dy * margin, class: 'system-edge', 'marker-end': 'url(#system-arrow)' })) line.setAttribute(key, String(value));
    const title = make('title'); title.textContent = edge.from + ' → ' + edge.to + ' (' + edge.type + ')';
    line.appendChild(title); svg.appendChild(line);
  }
  for (const node of graph.nodes) {
    const group = make('g'), rect = make('rect'), label = make('text');
    for (const [key, value] of Object.entries({ x: node.x, y: node.y, width: 180, height: 56,
      rx: 6, class: 'system-node' })) rect.setAttribute(key, String(value));
    for (const [key, value] of Object.entries({ x: node.x + 90, y: node.y + 32,
      'text-anchor': 'middle', class: 'system-label' })) label.setAttribute(key, String(value));
    label.textContent = node.label; group.appendChild(rect); group.appendChild(label); svg.appendChild(group);
    const item = document.createElement('li'), url = sourceURL(node.path, null);
    if (url) {
      const link = document.createElement('a'); link.href = url; link.textContent = node.label;
      link.target = '_blank'; link.rel = 'noopener noreferrer'; item.appendChild(link);
    } else item.textContent = node.label;
    links.appendChild(item);
  }
}
