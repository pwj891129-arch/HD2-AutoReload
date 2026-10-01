const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function checkMinimum(bytes) {
  assert(bytes.length >= 256 * bytes.readUInt32LE(8), 'Archive below native minimum size');
}
const oldMarker = Buffer.alloc(224);
oldMarker.writeUInt32LE(1, 8);
assert.throws(() => checkMinimum(oldMarker), /below native minimum/);

const stage = path.join(__dirname, 'dist/HD2-AutoReload-0.3.28-test');
const manifest = JSON.parse(fs.readFileSync(path.join(stage, 'manifest.json'), 'utf8'));
assert.equal(manifest.Options.length, 2);
assert(!manifest.Options.some(option => /F9|진단|실탄.*OFF|과열.*OFF/.test(option.Name)));
assert.equal(manifest.Options[0].SubOptions[0].Name, 'ON (기본)');
assert.equal(manifest.Options[1].SubOptions[0].Name, 'OFF (기본)');
const folders = ['.', ...manifest.Options.flatMap(option =>
  option.SubOptions.flatMap(variant => variant.Include))];
assert.equal(folders.length, 5);
assert.deepEqual(fs.readdirSync(stage).filter(file => fs.statSync(path.join(stage, file)).isDirectory()).sort(),
  folders.slice(1).sort(), 'No stale addon or diagnostic folders');
const archives = new Map();
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
  const offset = Number(bytes.readBigUInt64LE(120)), size = bytes.readUInt32LE(160);
  assert(offset + size <= bytes.length);
  assert.equal(offset % 16, 0);
  assert.equal(bytes.readUInt32LE(offset + 4), 2);
  assert.equal(bytes.readUInt32LE(offset), size - 8);
  const source = bytes.subarray(offset + 8, offset + size).toString('utf8');
  if (folder === '.') {
    assert(source.startsWith('-- HD2-Addon: mods/hd2_helper/auto_reload\n'));
    assert(source.includes('local VERSION = "0.3.28-test"'));
    assert(!source.includes('-- @'));
    for (const marker of ['TankProbe', 'SelfProbe', 'CatalogProbe', 'UnitLinkProbe',
      'HashTypeProbe', 'HASH_TYPE', 'TANK_PROBE', 'sample_legacy', 'autoreload_option_']) {
      assert(!source.includes(marker), 'Removed feature shipped: ' + marker);
    }
  } else {
    assert.equal(bytes.length, 256);
    assert.equal(source, folder.endsWith('_on') ? 'return true\n' : 'return false\n');
    assert(bytes.subarray(offset + size).every(value => value === 0));
  }
  archives.set(folder, {id, source});
  for (const suffix of ['.stream', '.gpu_resources']) {
    assert.equal(fs.statSync(file + suffix).size, 0);
  }
}
for (const option of manifest.Options) {
  const variants = option.SubOptions.map(variant => archives.get(variant.Include[0]));
  assert.equal(variants[0].id, variants[1].id, 'Exclusive ON/OFF variants set one resource');
  assert.notEqual(variants[0].source, variants[1].source);
}
// Test all deployments: no option, first variant, second variant, per feature.
for (const reload of [null, ...manifest.Options[0].SubOptions]) {
  for (const charge of [null, ...manifest.Options[1].SubOptions]) {
    const deployed = ['.', ...[reload, charge].flatMap(variant => variant?.Include ?? [])];
    const ids = deployed.map(folder => archives.get(folder).id);
    assert.equal(new Set(ids).size, ids.length, 'No duplicate Lua IDs in any valid deployment');
    assert(deployed.includes('.'), 'Default addon must deploy even with all options unchecked');
    const reloadValue = reload ? archives.get(reload.Include[0]).source === 'return true\n' : true;
    const chargeValue = charge ? archives.get(charge.Include[0]).source === 'return true\n' : false;
    if (!reload && !charge) {
      assert.equal(reloadValue, true);
      assert.equal(chargeValue, false);
    }
  }
}
console.log('PASS archive regression; default-on root addon, 4 exclusive option archives, 9 deployment combinations');
