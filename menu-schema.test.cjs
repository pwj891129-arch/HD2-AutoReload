const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const options = require('./arsenal-options.cjs');
const model = require('./menu-schema.cjs');
const filters = JSON.parse(fs.readFileSync(path.join(__dirname,'stratagem-filters.json')));
const texts = JSON.parse(fs.readFileSync(path.join(__dirname,'arsenal-text.json')));
const rows = model.schema(filters,texts);
assert.deepEqual([...model.languages].sort(),
  ['en','ko','ja','fr','de','it','es','es-419','pt','pt-BR','pl','ru','zh-Hans','zh-Hant'].sort());
assert.deepEqual(rows.map(row => row.key),options.definitions(filters).map(row => row.id));
assert.equal(new Set(rows.map(row => row.id)).size,47);
const counts = {};
for (const row of rows) {
  assert(row.id.length <= 96 && /^hd2_helper\.(autoreload|stratagem)\.[a-z0-9_]+$/.test(row.id));
  counts[row.category] = (counts[row.category] || 0) + 1;
  assert.deepEqual(Object.keys(row.text),model.languages);
  for (const language of model.languages) {
    const text = row.text[language];
    assert(text.label && text.mod && text.description);
    assert(Array.from(text.label).length <= 64 && Array.from(text.mod).length <= 40);
    assert(Array.from(text.description).length <= 400);
    if (!row.toggle) {
      assert(text.choices.length >= 2 && text.choices.length <= 16);
      assert(text.choices.every(item => Array.from(item).length <= 48));
    }
  }
}
assert.deepEqual(counts,{'hd2_helper.general':10,'hd2_helper.shared':5,'hd2_helper.mission':32});
assert(rows.find(row => row.key==='shared_reinforce').toggle);
assert.deepEqual(rows.find(row => row.key==='scale').values,[1,1.25,1.5,2,3]);
assert.deepEqual(rows.find(row => row.key==='railgun_threshold').values,[0.95,0.9]);
const direction = rows.find(row => row.key==='wheel_direction');
assert.deepEqual(direction.values,['counterclockwise','clockwise']);
assert.equal(direction.invalid,'counterclockwise');
assert.deepEqual(direction.text.en.choices,['Counterclockwise','Clockwise']);
assert.deepEqual(direction.text.ko.choices,['반시계방향','시계방향']);
assert.equal(fs.readFileSync(path.join(__dirname,'dist/menu-schema.generated.lua'),'utf8'),
  'return ' + model.literal(rows) + '\n');
console.log('PASS 47 options across 14 game languages: complete labels/descriptions/choices, stable IDs and text limits');
