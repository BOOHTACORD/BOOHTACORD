const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, 'filters.js'), 'utf8'), context);
const item = (source, release, runtime) => ({source_status: source, released: release, runtime});
const feature = {group: 'voice', platforms: {
  web: item('IN_SYNC', 'UNKNOWN', 'NOT_VERIFIED'), windows: item('BEHIND', 'UNKNOWN', 'NOT_VERIFIED'),
  macos: item('UNKNOWN', 'UNKNOWN', 'NOT_VERIFIED'), android: item('MISSING', 'UNKNOWN', 'NOT_RUN'),
  ios: {...item('UNKNOWN', 'UNKNOWN', 'NOT_VERIFIED'), applicability: 'PLATFORM_EXCEPTION'}}};

test('platform and source filters apply only to the selected platforms', () => {
  assert.equal(context.matchesFeature(feature, ['web'], 'voice', 'behind'), false);
  assert.equal(context.matchesFeature(feature, ['windows'], 'voice', 'behind'), true);
  assert.equal(context.matchesFeature(feature, ['android'], 'voice', 'differences'), true);
  assert.equal(context.matchesFeature(feature, ['ios'], 'voice', 'exceptions'), true);
  assert.equal(context.matchesFeature(feature, ['windows'], 'chat', 'all'), false);
  assert.equal(context.matchesFeature(feature, ['web'], 'voice', 'unverified'), true);
});
test('source, release and runtime layers remain independent', () => {
  const value = {...item('BEHIND', 'UNKNOWN', 'NOT_VERIFIED'), implemented_revision: 2, target_revision: 3};
  const source = context.formatCell(value, {source: true, release: false, runtime: false});
  assert.match(source, /BEHIND.*r2.*r3/);
  assert.doesNotMatch(source, /Релиз|Runtime/);
  const release = context.formatCell(value, {source: false, release: true, runtime: true});
  assert.match(release, /Релиз: UNKNOWN/);
  assert.match(release, /Runtime: NOT_VERIFIED/);
  assert.doesNotMatch(release, /BEHIND/);
});
