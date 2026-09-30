const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function checkMinimum(bytes) {
  assert(bytes.length >= 256 * bytes.readUInt32LE(8), 'Archive below native minimum size');
}
const oldMarker = Buffer.alloc(224);
oldMarker.writeUInt32LE(1, 8);
assert.throws(() => checkMinimum(oldMarker), /below native minimum/);

const stage = path.join(__dirname, 'dist/HD2-AutoReload-0.3.27-test');
const manifest = JSON.parse(fs.readFileSync(path.join(stage, 'manifest.json'), 'utf8'));
const folders = [...new Set(manifest.Options.flatMap(option => option.Include))];
const ids = new Set();
assert.equal(manifest.Options.length, 5);
assert.equal(folders.length, 6);
for (const folder of folders) {
  const files = fs.readdirSync(path.join(stage, folder)).filter(name => /\.patch_\d+$/.test(name));
  assert.equal(files.length, 1);
  const file = path.join(stage, folder, files[0]);
  const bytes = fs.readFileSync(file);
  checkMinimum(bytes);
  assert.equal(bytes.readUInt32LE(0), 0xf0000011);
  assert.equal(bytes.readUInt32LE(4), 1);
  assert.equal(bytes.readUInt32LE(8), 1);
  assert.equal(bytes.readBigUInt64LE(32), BigInt(bytes.length));
  assert.equal(bytes.readBigUInt64LE(80), 0xa14e8dfa2cd117e2n);
  assert.equal(bytes.readBigUInt64LE(112), 0xa14e8dfa2cd117e2n);
  const id = bytes.readBigUInt64LE(104).toString(16);
  assert(!ids.has(id)); ids.add(id);
  const offset = Number(bytes.readBigUInt64LE(120)), size = bytes.readUInt32LE(160);
  assert(offset + size <= bytes.length);
  assert.equal(offset % 16, 0);
  assert.equal(bytes.readUInt32LE(offset + 4), 2);
  assert.equal(bytes.readUInt32LE(offset), size - 8);
  const source = bytes.subarray(offset + 8, offset + size).toString('utf8');
  if (folder === 'Addon') {
    assert(source.startsWith('-- HD2-Addon: mods/hd2_helper/auto_reload\n'));
    assert(source.includes('local VERSION = "0.3.27-test"'));
    assert(!source.includes('-- @'));
  } else {
    assert.equal(bytes.length, 256);
    assert.equal(source, 'return true\n');
    assert(bytes.subarray(offset + size).every(value => value === 0));
  }
  for (const suffix of ['.stream', '.gpu_resources']) {
    assert.equal(fs.statSync(file + suffix).size, 0);
  }
}
console.log('PASS old-marker regression and 6 unique Lua archives; options are 256 bytes');
