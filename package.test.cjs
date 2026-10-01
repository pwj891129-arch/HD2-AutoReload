const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function checkMinimum(bytes) {
  assert(bytes.length >= 256 * bytes.readUInt32LE(8), 'Archive below native minimum size');
}
const oldMarker = Buffer.alloc(224);
oldMarker.writeUInt32LE(1, 8);
assert.throws(() => checkMinimum(oldMarker), /below native minimum/);

const version = '0.3.34-test';
const texts = JSON.parse(fs.readFileSync(path.join(__dirname, 'arsenal-text.json'), 'utf8'));
const filters = JSON.parse(fs.readFileSync(path.join(__dirname, 'stratagem-filters.json'), 'utf8'));
const coreIds = ['enabled', 'charge90', 'radial', 'hotkeys', 'shared_other', 'large', 'slow'];
const optionIds = [...coreIds, ...filters.map(filter => filter.id)];
const defaults = optionIds.map((_, index) => index < 4);
const kinds = filters.flatMap(filter => filter.kinds);
assert.equal(new Set(optionIds).size, optionIds.length, 'Filter resources are unique');
assert.equal(new Set(kinds).size, kinds.length, 'Every registered kind has exactly one toggle');
const capture = path.join(__dirname, '../BingusStratagemHotkeys/scratch');
if (fs.existsSync(path.join(capture, 'game-module.bin'))) {
  const image = fs.readFileSync(path.join(capture, 'game-module.bin'));
  const settings = fs.readFileSync(path.join(capture, 'stratagem-settings.bin'));
  const base = Number(image.readBigUInt64LE(0x348e8f8));
  const names = new Map();
  for (let kind = 1; kind <= 149; kind++) {
    const record = Number(image.readBigUInt64LE(0x37cb600 + kind * 8)) - base;
    assert(record >= 0 && record + 400 <= settings.length);
    const offset = Number(settings.readBigUInt64LE(record + 16)) - base;
    assert(offset >= 0 && offset < settings.length);
    names.set(kind, settings.subarray(offset, settings.indexOf(0, offset)).toString());
  }
  assert.equal(names.get(124), 'MISSIONS. REINFORCEMENT BEACON');
  assert.equal(names.get(145), 'MISSIONS. SOS Beacon');
  assert.equal(names.get(33), 'CONSUMABLES. RESUPPLY');
  for (const [id, expected] of Object.entries({
    shared_reinforce: ['TUTORIAL REINFORCEMENT BEACON', 'MISSIONS. REINFORCEMENT BEACON'],
    shared_sos: ['MISSIONS. SOS Beacon'], shared_resupply: ['CONSUMABLES. RESUPPLY'],
    mission_hellbomb: ['MISSIONS. HELLBOMB'], mission_seaf: ['MISSIONS. SEAF GUN'],
    mission_flag: ['MISSIONS. RAISE FLAG', 'MISSIONS. RAISE FLAG NO CLEAR AREA'],
    mission_cargo: ['MISSIONS. CARGO CONTAINER', 'MISSIONS. CARGO CONTAINER'],
    mission_discovery: ['MISSIONS. Upload Discovery']
  })) assert.deepEqual(filters.find(filter => filter.id === id).kinds.map(kind => names.get(kind)), expected,
    `Toggle matches native identity: ${id}`);
  for (const [kind, name] of names) {
    if (/^MISSIONS[. ]/.test(name)) assert(kinds.includes(kind), `Missing mission toggle: ${name}`);
  }
  for (const filter of filters.filter(filter => filter.id.startsWith('mission_'))) {
    for (const kind of filter.kinds) assert(/^(MISSIONS[. ]|\[TUTORIAL\] EXTRACTION|SEAF Squad)/.test(names.get(kind)), 'Mission filter targets a native mission');
  }
  console.log('PASS pinned catalog: common identities and complete native mission coverage');
} else console.log('SKIP pinned catalog: local reference capture unavailable');
function checkPackage(language) {
  const stage = path.join(__dirname, `dist/HD2-AutoReload-${version}-${language}`);
  const text = texts[language];
  const manifest = JSON.parse(fs.readFileSync(path.join(stage, 'manifest.json'), 'utf8'));
  assert.equal(manifest.Version, 1);
  assert.equal(manifest.Guid, '9d720fab-718f-4c91-93c5-31c4c3e6c42e');
  assert.equal(manifest.Name, `HD2 Helper Auto Reload + Stratagems ${version}`);
  assert.equal(manifest.Description, `${version}. ${text.Description}`);
  assert.deepEqual(Object.keys(manifest).sort(), ['Description', 'Guid', 'Name', 'Options', 'Version']);
  assert.deepEqual(Object.keys(text.Options), coreIds);
  assert.equal(manifest.Options.length, optionIds.length);
  assert(!manifest.Options.some(option => /F9|진단|실탄.*OFF|과열.*OFF/.test(option.Name)));
  for (let i = 0; i < optionIds.length; i++) {
    const option = manifest.Options[i], id = optionIds[i];
    const filter = filters.find(filter => filter.id === id);
    const localized = filter ? {Name: filter[language], Description: text.FilterDescription} : text.Options[id];
    assert.deepEqual(Object.keys(option).sort(), ['Description', 'Image', 'Name', 'SubOptions']);
    assert.equal(option.Name, localized.Name);
    assert.equal(option.Description, localized.Description);
    assert(option.Name.trim() && option.Description.trim());
    assert.equal(option.Image, `OptionIcons/${id}.png`);
    const image = fs.readFileSync(path.join(stage, option.Image));
    assert(image.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')));
    assert.equal(image.readUInt32BE(16), 256); assert.equal(image.readUInt32BE(20), 256);
    assert.equal(option.SubOptions.length, 2);
    for (const [index, variant] of option.SubOptions.entries()) {
      const value = index === 0 ? defaults[i] : !defaults[i];
      assert.deepEqual(Object.keys(variant).sort(), ['Description', 'Image', 'Include', 'Name']);
      assert.equal(variant.Image, option.Image);
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
  assert.equal(folders.length, 1 + optionIds.length * 2);
  assert.deepEqual(fs.readdirSync(stage).filter(file => fs.statSync(path.join(stage, file)).isDirectory()).sort(),
    [...folders, 'OptionIcons'].sort(), 'Only patch folders and image previews are packaged');
  assert.deepEqual(fs.readdirSync(path.join(stage, 'OptionIcons')).sort(), optionIds.map(id => id + '.png').sort());
  assert(fs.readFileSync(path.join(stage, 'LUCIDE-LICENSE.txt')).equals(
    fs.readFileSync(path.join(__dirname, 'assets/LUCIDE-LICENSE.txt'))), 'Unmodified icon license ships');
  const previousStage = path.join(__dirname, `dist/HD2-AutoReload-0.3.33-test-${language}`);
  if (fs.existsSync(path.join(previousStage, 'manifest.json'))) {
    const previous = JSON.parse(fs.readFileSync(path.join(previousStage, 'manifest.json'), 'utf8'));
    const withoutImages = option => Object.fromEntries(Object.entries(option).filter(([key]) => key !== 'Image')
      .map(([key, value]) => [key, key === 'SubOptions' ? value.map(withoutImages) : value]));
    assert.deepEqual(manifest.Options.map(withoutImages), previous.Options, 'Existing order, text, defaults and includes are unchanged');
  }
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
      const previousFile = path.join(previousStage, 'Core', files[0]);
      if (fs.existsSync(previousFile)) {
        const previous = fs.readFileSync(previousFile);
        const at = Number(previous.readBigUInt64LE(120)), length = previous.readUInt32LE(160);
        const previousSource = previous.subarray(at + 8, at + length).toString('utf8');
        assert.equal(source, previousSource.replaceAll('0.3.33-test', version), 'Only version metadata changes in the game Lua');
      }
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
      assert(source.includes('shared_visible(include_shared, kind)'));
      assert(source.includes('local visibility = {other = option("shared_other", false)}'));
      assert(!source.includes('option("shared", false)'), 'Retired master toggle cannot override individual choices');
      for (const filter of filters) assert(source.includes(`{id = "${filter.id}", kinds = {${filter.kinds.join(', ')}}}`));
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
  const resourceIds = new Set([archives.get('Core').id]);
  for (const option of manifest.Options) {
    for (const variant of option.SubOptions) assert(variant.Include.includes('Core'), 'Every ON/OFF choice deploys the addon');
    const variants = option.SubOptions.map(variant => archives.get(variant.Include.find(folder => folder !== 'Core')));
    assert.equal(variants[0].id, variants[1].id, 'Exclusive ON/OFF variants set one resource');
    assert.notEqual(variants[0].source, variants[1].source);
    assert(!resourceIds.has(variants[0].id), 'Different settings have different Lua IDs');
    resourceIds.add(variants[0].id);
  }
  // Exhaust base controls; cover every filter and every pair without exponential growth.
  let combinations = 0;
  function checkDeployment(selected) {
    const deployed = [...new Set(selected.flatMap(variant => variant?.Include ?? []))];
    const ids = deployed.map(folder => archives.get(folder).id);
    assert.equal(new Set(ids).size, ids.length, 'No duplicate Lua IDs in any valid deployment');
    assert.equal(deployed.includes('Core'), selected.some(Boolean), 'Any selected setting deploys one common addon');
    const values = selected.map((variant, i) => variant ?
      archives.get(variant.Include.find(folder => folder !== 'Core')).source === 'return true\n' : defaults[i]);
    for (let i = 0; i < selected.length; i++) {
      const variant = selected[i];
      assert.equal(values[i], variant ? variant.Include.includes(`Option_${optionIds[i]}_on`) : defaults[i]);
    }
    if (selected.every(variant => variant === null)) {
      assert.equal(deployed.length, 0, 'All unchecked intentionally deploys no feature files');
      assert.deepEqual(values, defaults);
    }
    combinations++;
  }
  const baseIndices = [0, 1, 2, 3, 5, 6];
  const omitted = () => Array(optionIds.length).fill(null);
  function deployment(index, selected) {
    if (index === baseIndices.length) return checkDeployment(selected);
    const at = baseIndices[index];
    for (const variant of [null, ...manifest.Options[at].SubOptions]) {
      const next = [...selected]; next[at] = variant; deployment(index + 1, next);
    }
  }
  deployment(0, omitted());
  for (let first = 0; first < optionIds.length; first++) {
    for (let second = first + 1; second < optionIds.length; second++) {
      for (const a of [null, ...manifest.Options[first].SubOptions]) {
        for (const b of [null, ...manifest.Options[second].SubOptions]) {
          const selected = omitted(); selected[first] = a; selected[second] = b; checkDeployment(selected);
        }
      }
    }
  }
  for (const value of [true, false]) checkDeployment(manifest.Options.map((option, i) =>
    option.SubOptions[defaults[i] === value ? 0 : 1]));
  checkDeployment(manifest.Options.map(option => option.SubOptions[0]));
  assert.equal(combinations, 3 ** baseIndices.length + 9 * optionIds.length * (optionIds.length - 1) / 2 + 3);
  console.log(`PASS ${language}: ${optionIds.length} localized toggles, ${optionIds.length * 2} option archives, ${combinations} deployment scenarios`);
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
assert.equal(files.length, 8 + optionIds.length * 7);
assert.deepEqual(files, packageFiles(korean.stage));
for (const file of files.filter(file => file !== 'manifest.json')) {
  assert(fs.readFileSync(path.join(english.stage, file)).equals(fs.readFileSync(path.join(korean.stage, file))),
    `Language packages have different payloads: ${file}`);
}
console.log('PASS English/Korean packages: same GUID, option order, defaults, paths and byte-identical payloads');
