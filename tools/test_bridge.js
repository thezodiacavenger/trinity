// Run: node tools/test_bridge.js   (tests the pure logic of the Apps Script bridge)
require.extensions['.gs'] = require.extensions['.js'];
const assert = require('assert');
const { categorize, summarize } = require('../bridge/google-apps-script/Code.gs');
const d = (h, m = 0) => new Date(2026, 10, 5, h, m);

assert.strictEqual(categorize('Weekly ops review', 6), 'MTG');
assert.strictEqual(categorize('Inventory aging deep work', 0), 'FOCUS');
assert.strictEqual(categorize('Gym - legs', 0), 'TRAIN');
assert.strictEqual(categorize('Lunch w/ CFO', 1), 'LUNCH');
assert.strictEqual(categorize('Reading: High Output Management', 0), 'READ');
assert.strictEqual(categorize('Kids pickup', 0), 'PERS');
assert.strictEqual(categorize('Spreadsheet cleanup', 0), 'FOCUS', 'no false match on "read" inside spreadsheet');

const day = [
  { title: 'Run 10k', start: d(6), end: d(7), guests: 0 },
  { title: 'Exec sync', start: d(9), end: d(10), guests: 4 },
  { title: 'Vendor call', start: d(11), end: d(11, 30), guests: 2 },
  { title: 'Lunch', start: d(12), end: d(13), guests: 0 },
  { title: 'Read', start: d(21), end: d(21, 30), guests: 0 },
];
const s = summarize(day, d(10, 20));
assert.deepStrictEqual([s.meet, s.train, s.lunch, s.read, s.nIn, s.nCat], [90, 60, 60, 30, 40, 'MTG']);
const json = JSON.stringify(s);
assert(!/Exec|Vendor|Run 10k/.test(json), 'titles must never leave the bridge');
console.log('bridge logic OK:', json);
