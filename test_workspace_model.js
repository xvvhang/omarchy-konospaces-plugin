const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const policy = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, 'WorkspaceModel.js'), 'utf8'), policy);
const clean = value => JSON.parse(JSON.stringify(value));
const ws = (id, name, monitorName = 'A', count = 1) => ({id, name, monitorName, windows: Array(count).fill({})});
const data = [
  ws(1, '1'), ws(3, '3', 'A', 0), ws(11, '11', 'B'), ws(-1300, 'design'),
  ws(-99, 'special:minimized'), ws(-98, 'special:qconsole'),
  ws(-97, 'special:scratchpad'), ws(-96, 'special:screensaver'),
  ws(-95, 'special:notes'), ws(-94, 'special:<img src="https://example.invalid">')
];
const monitors = [{name: 'A', specialWorkspace: {name: 'special:qconsole'}}, {name: 'B', specialWorkspace: {name: ''}}];
let groups = clean(policy.partition(data, 'A', 0, 3, monitors));
assert.deepEqual(groups.regular.map(w => w.name), ['1', '3', 'design']);
assert.deepEqual(groups.overlays.map(w => w.name).slice(0, 2), ['special:scratchpad', 'special:qconsole']);
assert.ok(!groups.overlays.some(w => ['special:minimized', 'special:screensaver'].includes(w.name)));
assert.ok(groups.overlays.some(w => w.name === 'special:notes'));
groups = clean(policy.partition(data, 'B', 1, 11, monitors));
assert.deepEqual(groups.regular.map(w => w.name), ['11']);
assert.ok(!groups.overlays.some(w => w.name === 'special:qconsole'));
assert.equal(policy.label(ws(11, '11', 'B'), 1), '1');
assert.equal(policy.label(ws(20, '20', 'B'), 1), '10');
assert.equal(policy.label(ws(-1300, 'design'), 0), 'design');
assert.equal(policy.kind('floating'), 'regular');
assert.equal(policy.kind('special:minimized-copy'), 'overlay');
assert.equal(policy.label(ws(-98, 'special:qconsole'), 0), '>_');
assert.equal(policy.isViewed(ws(3, '3', 'A', 0), 3, ''), true); // empty viewed workspace
assert.equal(policy.isViewed(ws(3, '3'), 3, 'special:qconsole'), false);
assert.equal(policy.isViewed(ws(3, '3'), 3, 'special:scratchpad'), false);
assert.equal(policy.isViewed(ws(-97, 'special:scratchpad'), 3, 'special:scratchpad'), true);
assert.equal(policy.isViewed(ws(3, '3'), 3, ''), true); // restored after closing the overlay
for (const opened of ['', 'special:qconsole', 'special:scratchpad']) {
  const candidates = [ws(3, '3'), ws(-97, 'special:scratchpad'), ws(-98, 'special:qconsole')];
  assert.equal(candidates.filter(w => policy.isViewed(w, 3, opened)).length, 1);
}
assert.equal(policy.isViewed(ws(1, '1'), 3, ''), false);
assert.equal(policy.isViewed(ws(-98, 'special:qconsole'), 3, 'special:qconsole'), true);
assert.equal(policy.isViewed(ws(-97, 'special:scratchpad'), 3, 'special:qconsole'), false);
assert.equal(policy.isViewed(ws(-99, 'special:minimized'), -99, ''), false);
assert.equal(policy.windowActive(false, true), false); // hidden overlay retains stale window focus
assert.equal(policy.windowActive(false, false), false);
assert.equal(policy.windowActive(true, false), false);
assert.equal(policy.windowActive(true, true), true);
assert.equal(policy.icon('1'), '');
assert.equal(policy.icon('special:qconsole'), '\uf489');
assert.equal(policy.icon('special:scratchpad'), '\u{f014c}');
assert.equal(policy.icon('special:minimized'), '\u{f10ac}');
assert.equal([...policy.icon('special:notes')].length, 1);
assert.equal(policy.origin(['omarchy-minimized-from-3']), 3);
assert.equal(policy.origin(['omarchy-minimized-from-3', 'omarchy-minimized-from-4']), 0);
assert.equal(policy.origin(['omarchy-minimized-from-0', 'other']), 0);
assert.equal(policy.safeTooltip('<img src="https://example.invalid">&'), '&lt;img src="https://example.invalid"&gt;&amp;');
assert.equal(policy.safeTooltip(policy.label(ws(-42, 'special:<b>notes</b>'), 0)), '&lt;b&gt;notes&lt;/b&gt;');
console.log('Workspace classification, multi-monitor, origin and tooltip tests passed');
