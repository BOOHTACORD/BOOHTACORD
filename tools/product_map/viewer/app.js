const platforms = ['web', 'windows', 'macos', 'android', 'ios'];
const rows = document.getElementById('rows');
const search = document.getElementById('search');
const count = document.getElementById('count');
const detail = document.getElementById('detail');
function cell(row, value) {
  const node = document.createElement('td');
  node.textContent = value;
  row.appendChild(node);
}
function render() {
  rows.replaceChildren();
  const query = search.value.trim().toLocaleLowerCase();
  let visible = 0;
  for (const feature of data) {
    if (!(feature.id + ' ' + feature.description).toLocaleLowerCase().includes(query)) continue;
    const row = document.createElement('tr');
    const heading = document.createElement('th');
    heading.scope = 'row';
    const link = document.createElement('a');
    link.href = '#feature/' + encodeURIComponent(feature.id);
    link.textContent = feature.id;
    heading.append(link, document.createElement('br'), document.createTextNode(feature.description));
    row.appendChild(heading);
    for (const name of platforms) {
      const item = feature.platforms[name];
      cell(row, 'Код: ' + item.source_status + '\nРелиз: ' + item.released + '\nRuntime: ' + item.runtime);
    }
    rows.appendChild(row);
    visible++;
  }
  count.textContent = 'Сценариев: ' + visible;
}
search.addEventListener('input', render);
function selectHash() {
  const match = location.hash.match(/^#feature\/(.*)$/);
  if (!match) return;
  try {
    search.value = decodeURIComponent(match[1]);
    render();
    const feature = data.find(item => item.id === search.value);
    detail.replaceChildren();
    if (!feature) { detail.textContent = 'Сценарий не найден.'; return; }
    const title = document.createElement('h3');
    title.textContent = feature.title || feature.id;
    detail.appendChild(title);
    const components = feature.components || [];
    if (!components.length) { detail.append('Компоненты пока не описаны.'); return; }
    const list = document.createElement('ul');
    for (const component of components) {
      const item = document.createElement('li');
      item.textContent = component.id + ': ' + component.paths.join(', ');
      list.appendChild(item);
    }
    detail.appendChild(list);
    const edges = feature.component_edges || [];
    const graphTitle = document.createElement('h4');
    graphTitle.textContent = 'Связи компонентов';
    detail.appendChild(graphTitle);
    if (!edges.length) { detail.append('Связи пока не описаны.'); return; }
    const graph = document.createElement('ul');
    for (const edge of edges) {
      const line = document.createElement('li');
      line.textContent = edge.from + ' → ' + edge.to + ' (зависит от)';
      graph.appendChild(line);
    }
    detail.appendChild(graph);
  } catch (_) { detail.textContent = 'Некорректная ссылка.'; }
}
window.addEventListener('hashchange', selectHash);
render();
selectHash();
