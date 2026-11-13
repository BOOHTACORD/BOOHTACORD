function sourceURL(path, revision) {
  if (typeof path !== 'string' || !path || path.length > 4096 || /[\\:\x00-\x1f\x7f]/.test(path) ||
      path.split('/').some(part => !part || part === '.' || part === '..')) return null;
  if (revision != null && (typeof revision !== 'string' || !/^[0-9a-f]{40}$/.test(revision))) return null;
  const ref = revision == null ? 'master' : revision;
  return 'https://github.com/BOOHTACORD/BOOHTACORD/blob/' + ref + '/' + path.split('/').map(encodeURIComponent).join('/');
}
function issueURL(value) {
  return Number.isSafeInteger(value) && value > 0 ? 'https://github.com/BOOHTACORD/BOOHTACORD/issues/' + value : null;
}
function externalLink(url, label) {
  const link = document.createElement('a');
  link.href = url; link.textContent = label; link.target = '_blank'; link.rel = 'noopener noreferrer';
  return link;
}
function renderDetail(feature, detail) {
  detail.replaceChildren();
  if (!feature) { detail.textContent = 'Сценарий не найден.'; return; }
  const title = document.createElement('h3'); title.textContent = feature.title || feature.id; detail.appendChild(title);
  const issue = issueURL(feature.issue);
  if (issue) { const p = document.createElement('p'); p.appendChild(externalLink(issue, 'Задача #' + feature.issue)); detail.appendChild(p); }
  if ((feature.depends_on || []).length) {
    const heading = document.createElement('h4'); heading.textContent = 'Зависит от функций'; detail.appendChild(heading);
    const dependencies = document.createElement('ul');
    for (const identifier of feature.depends_on) {
      const item = document.createElement('li'), link = document.createElement('a');
      link.href = '#feature/' + encodeURIComponent(identifier); link.textContent = identifier;
      item.appendChild(link); dependencies.appendChild(item);
    }
    detail.appendChild(dependencies);
  }
  const components = feature.components || [];
  if (!components.length) { detail.append('Компоненты пока не описаны.'); return; }
  const note = document.createElement('p');
  note.textContent = feature.source_revision == null ? 'Исходники в master, без привязки к SHA.' : 'Исходники по указанному SHA; происхождение не подтверждено.';
  detail.appendChild(note);
  const list = document.createElement('ul');
  for (const component of components) {
    const item = document.createElement('li');
    item.append(document.createTextNode(component.id + ': '));
    component.paths.forEach((path, index) => {
      if (index) item.append(document.createTextNode(', '));
      const url = sourceURL(path, feature.source_revision);
      item.append(url ? externalLink(url, path) : document.createTextNode(path));
    });
    list.appendChild(item);
  }
  detail.appendChild(list);
  const edges = feature.component_edges || [], heading = document.createElement('h4');
  heading.textContent = 'Связи компонентов'; detail.appendChild(heading);
  if (!edges.length) { detail.append('Связи пока не описаны.'); return; }
  const graph = document.createElement('ul');
  for (const edge of edges) {
    const line = document.createElement('li');
    line.textContent = edge.from + ' → ' + edge.to + ' (зависит от)'; graph.appendChild(line);
  }
  detail.appendChild(graph);
}
