const platforms = ['web', 'windows', 'macos', 'android', 'ios'];
const rows = document.getElementById('rows');
const search = document.getElementById('search');
const count = document.getElementById('count');
const detail = document.getElementById('detail');
const header = document.getElementById('header');
const platform = document.getElementById('platform'), domain = document.getElementById('domain');
const status = document.getElementById('status');
const sourceLayer = document.getElementById('layer-source'), releaseLayer = document.getElementById('layer-release');
const runtimeLayer = document.getElementById('layer-runtime');
const names = {web: 'Web', windows: 'Windows', macos: 'macOS', android: 'Android', ios: 'iOS'};
for (const name of [...new Set(data.map(item => item.group).filter(Boolean))].sort()) {
  const option = document.createElement('option'); option.value = name; option.textContent = name; domain.appendChild(option);
}
function cell(row, value) {
  const node = document.createElement('td');
  node.textContent = value;
  row.appendChild(node);
}
function render() {
  rows.replaceChildren();
  const selected = platforms.includes(platform.value) ? [platform.value] : platforms;
  const layers = {source: sourceLayer.checked, release: releaseLayer.checked, runtime: runtimeLayer.checked};
  header.replaceChildren();
  for (const name of ['Сценарий', ...selected.map(value => names[value])]) {
    const th = document.createElement('th'); th.scope = 'col'; th.textContent = name; header.appendChild(th);
  }
  const query = search.value.trim().toLocaleLowerCase();
  let visible = 0;
  for (const feature of data) {
    if (!(feature.id + ' ' + (feature.title || '') + ' ' + feature.description).toLocaleLowerCase().includes(query) ||
        !matchesFeature(feature, selected, domain.value || 'all', status.value || 'all')) continue;
    const row = document.createElement('tr');
    const heading = document.createElement('th');
    heading.scope = 'row';
    const link = document.createElement('a');
    link.href = '#feature/' + encodeURIComponent(feature.id);
    link.textContent = feature.id;
    heading.append(link, document.createElement('br'), document.createTextNode(feature.description));
    row.appendChild(heading);
    for (const name of selected) {
      const item = feature.platforms[name];
      cell(row, formatCell(item, layers));
    }
    rows.appendChild(row);
    visible++;
  }
  count.textContent = 'Сценариев: ' + visible;
}
search.addEventListener('input', render);
for (const control of [platform, domain, status, sourceLayer, releaseLayer, runtimeLayer]) control.addEventListener('change', render);
function selectHash() {
  const match = location.hash.match(/^#feature\/(.*)$/);
  if (!match) return;
  try {
    search.value = decodeURIComponent(match[1]);
    domain.value = 'all'; status.value = 'all';
    render();
    const feature = data.find(item => item.id === search.value);
    renderDetail(feature, detail);
  } catch (_) { detail.textContent = 'Некорректная ссылка.'; }
}
window.addEventListener('hashchange', selectHash);
render();
selectHash();
