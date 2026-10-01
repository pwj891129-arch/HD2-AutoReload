const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function checkMinimum(bytes) {
  assert(bytes.length >= 256 * bytes.readUInt32LE(8), 'Archive below native minimum size');
}
const oldMarker = Buffer.alloc(224);
oldMarker.writeUInt32LE(1, 8);
assert.throws(() => checkMinimum(oldMarker), /below native minimum/);

const version = '0.3.31-test';
const texts = JSON.parse(fs.readFileSync(path.join(__dirname, 'arsenal-text.json'), 'utf8'));
const optionIds = ['enabled', 'charge90', 'radial', 'hotkeys', 'shared', 'large', 'slow'];
function checkPackage(language) {
  const stage = path.join(__dirname, `dist/HD2-AutoReload-${version}-${language}`);
  const text = texts[language];
  const manifest = JSON.parse(fs.readFileSync(path.join(stage, 'manifest.json'), 'utf8'));
  assert.equal(manifest.Version, 1);
  assert.equal(manifest.Guid, '9d720fab-718f-4c91-93c5-31c4c3e6c42e');
  assert.equal(manifest.Name, `HD2 Helper Auto Reload + Stratagems ${version}`);
  assert.equal(manifest.Description, `${version}. ${text.Description}`);
  assert.deepEqual(Object.keys(manifest).sort(), ['Description', 'Guid', 'Name', 'Options', 'Version']);
  assert.deepEqual(Object.keys(text.Options), optionIds);
  assert.equal(manifest.Options.length, 7);
  assert(!manifest.Options.some(option => /F9|진단|실탄.*OFF|과열.*OFF/.test(option.Name)));
  for (let i = 0; i < 7; i++) {
    const option = manifest.Options[i], id = optionIds[i];
    assert.deepEqual(Object.keys(option).sort(), ['Description', 'Name', 'SubOptions']);
    assert.equal(option.Name, text.Options[id].Name);
    assert.equal(option.Description, text.Options[id].Description);
    assert(option.Name.trim() && option.Description.trim());
    assert.equal(option.SubOptions.length, 2);
    for (const [index, variant] of option.SubOptions.entries()) {
      const value = index === 0 ? i < 4 : i >= 4;
      assert.deepEqual(Object.keys(variant).sort(), ['Description', 'Include', 'Name']);
      assert.equal(variant.Name, (value ? 'ON' : 'OFF') + (index === 0 ? ` (${text.Default})` : ''));
      assert.equal(variant.Description, value ? text.Enabled : text.Disabled);
      assert.deepEqual(variant.Include, ['Core', `Option_${id}_${value ? 'on' : 'off'}`]);
    }
  }
  const visibleText = [manifest.Description, ...manifest.Options.flatMap(option =>
    [option.Name, option.Description, ...option.SubOptions.flatMap(variant => [variant.Name, variant.Description])])];
  if (language === 'en') assert(visibleText.every(value => /^[\x20-\x7e]+$/.test(value)), 'English UI text is ASCII');
  else assert(visibleText.every(value => /[가-힣]/.test(value) || /^(ON|OFF)$/.test(value)), 'Korean UI text is localized');
  const folders = [...new Set(manifest.Options.flatMap(option =>
    option.SubOptions.flatMap(variant => variant.Include)))];
  assert.equal(folders.length, 15);
  assert.deepEqual(fs.readdirSync(stage).filter(file => fs.statSync(path.join(stage, file)).isDirectory()).sort(),
    [...folders].sort(), 'No stale addon or diagnostic folders');
  assert(!fs.readdirSync(stage).some(name => /\.patch_\d+$/.test(name)), 'No root-only addon dependency');
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
    if (folder === 'Core') {
      assert(source.startsWith('-- HD2-Addon: mods/hd2_helper/auto_reload\n'));
      assert(source.includes(`local VERSION = "${version}"`));
      assert(source.includes('start_feature("stratagem", function()'));
      assert(source.includes('start_feature("autoreload", function()'));
      assert(source.indexOf('start_feature("stratagem", function()') < source.indexOf('start_feature("autoreload", function()'));
      assert(source.includes('charge90 = setting("charge90", true)'));
      assert(source.includes('HD2StratagemHotkeys'));
      assert(source.includes('state.mouse_release or native_active'));
      assert(source.includes('INPUT mouse-release-replayed'));
      assert(source.includes('node >= 1048576 or seen[node]'));
      assert(source.includes('sr.Gui.bitmap_uv(icon.gui, data.material'));
      assert(!source.includes('node >= capacity'));
      assert(!/WriteProcessMemory|VirtualProtect|set_resource_override/.test(source));
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
    for (const variant of option.SubOptions) assert(variant.Include.includes('Core'), 'Every ON/OFF choice deploys the addon');
    const variants = option.SubOptions.map(variant => archives.get(variant.Include.find(folder => folder !== 'Core')));
    assert.equal(variants[0].id, variants[1].id, 'Exclusive ON/OFF variants set one resource');
    assert.notEqual(variants[0].source, variants[1].source);
  }
  // Each setting has three valid states: omitted, default, or explicit opposite.
  let combinations = 0;
  function deployment(index, selected) {
    if (index === manifest.Options.length) {
      const deployed = [...new Set(selected.flatMap(variant => variant?.Include ?? []))];
      const ids = deployed.map(folder => archives.get(folder).id);
      assert.equal(new Set(ids).size, ids.length, 'No duplicate Lua IDs in any valid deployment');
      assert.equal(deployed.includes('Core'), selected.some(Boolean), 'Any selected setting deploys one common addon');
      const values = selected.map((variant, i) => variant ?
        archives.get(variant.Include.find(folder => folder !== 'Core')).source === 'return true\n' : i < 4);
      if (selected.every(variant => variant === null)) {
        assert.equal(deployed.length, 0, 'All unchecked intentionally deploys no feature files');
        assert.deepEqual(values, [true, true, true, true, false, false, false]);
      }
      combinations++;
      return;
    }
    for (const variant of [null, ...manifest.Options[index].SubOptions]) {
      deployment(index + 1, [...selected, variant]);
    }
  }
  deployment(0, []);
  assert.equal(combinations, 2187);
  console.log(`PASS ${language}: localized labels, common Lua-only addon, 14 option archives, 2187 deployment combinations`);
  return {stage, manifest};
}
const english = checkPackage('en'), korean = checkPackage('ko');
function withoutText(value) {
  if (Array.isArray(value)) return value.map(withoutText);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'Name' && key !== 'Description')
    .map(([key, child]) => [key, withoutText(child)]));
}
assert.deepEqual(withoutText(english.manifest), withoutText(korean.manifest), 'Only display text may differ');
function packageFiles(folder, relative = '') {
  return fs.readdirSync(path.join(folder, relative), {withFileTypes: true}).flatMap(entry => {
    const file = path.join(relative, entry.name);
    return entry.isDirectory() ? packageFiles(folder, file) : [file];
  }).sort();
}
const files = packageFiles(english.stage);
assert.equal(files.length, 49);
assert.deepEqual(files, packageFiles(korean.stage));
for (const file of files.filter(file => file !== 'manifest.json')) {
  assert(fs.readFileSync(path.join(english.stage, file)).equals(fs.readFileSync(path.join(korean.stage, file))),
    `Language packages have different payloads: ${file}`);
}
console.log('PASS English/Korean packages: same GUID, option order, defaults, paths and byte-identical payloads');
