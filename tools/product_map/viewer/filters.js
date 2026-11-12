function matchesFeature(feature, selected, group, filter) {
  if (group !== 'all' && feature.group !== group) return false;
  if (filter === 'all') return true;
  return selected.some(name => {
    const item = feature.platforms[name];
    if (filter === 'behind') return item.source_status === 'BEHIND';
    if (filter === 'differences') return ['BEHIND', 'AHEAD_UNREVIEWED', 'MISSING', 'INTENTIONAL_DIFFERENCE'].includes(item.source_status);
    if (filter === 'exceptions') return ['PLATFORM_EXCEPTION', 'NOT_APPLICABLE'].includes(item.applicability);
    if (filter === 'unverified') return item.source_status === 'UNKNOWN' || item.released === 'UNKNOWN' || ['NOT_VERIFIED', 'NOT_RUN', 'BLOCKED'].includes(item.runtime);
    return false;
  });
}

function formatCell(item, layers) {
  const lines = [];
  if (layers.source) {
    const revision = value => Number.isInteger(value) && value > 0 ? 'r' + value : '?';
    const versions = item.implemented_revision != null || item.target_revision != null
      ? ' (' + revision(item.implemented_revision) + ' → ' + revision(item.target_revision) + ')' : '';
    lines.push('Код: ' + item.source_status + versions);
  }
  if (layers.release) lines.push('Релиз: ' + item.released);
  if (layers.runtime) lines.push('Runtime: ' + item.runtime);
  return lines.length ? lines.join('\n') : 'Слои не выбраны';
}
