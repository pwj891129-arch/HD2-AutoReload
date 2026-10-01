const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const optionModel = require('./arsenal-options.cjs');

function checkMinimum(bytes) {
  assert(bytes.length >= 256 * bytes.readUInt32LE(8), 'Archive below native minimum size');
}
const oldMarker = Buffer.alloc(224);
oldMarker.writeUInt32LE(1, 8);
assert.throws(() => checkMinimum(oldMarker), /below native minimum/);

const version = '0.3.40-test';
const texts = JSON.parse(fs.readFileSync(path.join(__dirname, 'arsenal-text.json'), 'utf8'));
const filters = JSON.parse(fs.readFileSync(path.join(__dirname, 'stratagem-filters.json'), 'utf8'));
const nativeIcons = JSON.parse(fs.readFileSync(path.join(__dirname, 'assets/native-option-icons.json'), 'utf8'));
const coreIds = ['enabled', 'charge90', 'radial', 'hotkeys', 'shared_other', 'scale', 'slow',
  'shared_all', 'mission_all', 'shared_mission_all'];
const definitions = optionModel.definitions(filters);
const optionIds = definitions.map(option => option.id);
const defaults = definitions.map(option => option.toggle ? false : option.values[0]);
const variantsFor = option => option.SubOptions ?? [option];
const variantCount = definitions.reduce((sum, option) => sum + option.values.length, 0);
assert.equal(optionIds.length, 44);
assert.equal(variantCount, 55);
assert.equal(definitions.filter(option => option.toggle).length, 39);
assert.deepEqual(definitions.find(option => option.id === 'scale').values, [1, 1.5, 2, 3, 4]);
for (const id of ['shared_all', 'mission_all', 'shared_mission_all']) {
  assert.deepEqual(definitions.find(option => option.id === id).values, ['individual', true, false]);
}
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
    const localized = filter ? {Name: filter[language], Description: text.FilterDescription + ' ' +
      (nativeIcons.icons[id].source === 'game' ? text.NativeIconDescription : text.FallbackIconDescription)} : text.Options[id];
    assert.deepEqual(Object.keys(option).sort(), definitions[i].toggle ?
      ['Description', 'Image', 'Include', 'Name'] : ['Description', 'Image', 'Name', 'SubOptions']);
    assert.equal(option.Name, localized.Name);
    assert.equal(option.Description, localized.Description);
    assert(option.Name.trim() && option.Description.trim());
    assert.equal(option.Image, `OptionIcons/${id}.png`);
    const image = fs.readFileSync(path.join(stage, option.Image));
    assert(image.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')));
    assert.equal(image.readUInt32BE(16), 256); assert.equal(image.readUInt32BE(20), 256);
    if (filter) assert.equal(crypto.createHash('sha256').update(image).digest('hex'),
      nativeIcons.icons[id].pngSha256, 'Staged preview matches native/fallback provenance');
    if (definitions[i].toggle) {
      assert(!option.SubOptions, 'Checkboxes have no hidden ON/OFF child selection');
      assert.deepEqual(option.Include, ['Core', `Option_${id}_on`], 'Checked checkbox deploys only ON');
      continue;
    }
    assert.equal(option.SubOptions.length, definitions[i].values.length);
    for (const [index, variant] of option.SubOptions.entries()) {
      const value = definitions[i].values[index];
      assert.deepEqual(Object.keys(variant).sort(), ['Description', 'Image', 'Include', 'Name']);
      assert.equal(variant.Image, option.Image);
      assert.equal(variant.Name, optionModel.label(value, text, id) + (index === 0 ? ` (${text.Default})` : ''));
      assert.equal(variant.Description, optionModel.description(value, text, id));
      assert.deepEqual(variant.Include, ['Core', `Option_${id}_${optionModel.suffix(value)}`]);
    }
  }
  const visibleText = [manifest.Description, ...manifest.Options.flatMap(option =>
    [option.Name, option.Description, ...(option.SubOptions ?? []).flatMap(variant => [variant.Name, variant.Description])])];
  if (language === 'en') assert(visibleText.every(value => /^[\x20-\x7e]+$/.test(value)), 'English UI text is ASCII');
  else assert(visibleText.every(value => /[가-힣]/.test(value) || /^(ON|OFF|\d+%|\d+ ms)$/.test(value)), 'Korean UI text is localized');
  const folders = [...new Set(manifest.Options.flatMap(option =>
    variantsFor(option).flatMap(variant => variant.Include)))];
  assert.equal(folders.length, 1 + variantCount);
  assert.deepEqual(fs.readdirSync(stage).filter(file => fs.statSync(path.join(stage, file)).isDirectory()).sort(),
    [...folders, 'OptionIcons'].sort(), 'Only patch folders and image previews are packaged');
  assert.deepEqual(fs.readdirSync(path.join(stage, 'OptionIcons')).sort(), optionIds.map(id => id + '.png').sort());
  assert(fs.readFileSync(path.join(stage, 'LUCIDE-LICENSE.txt')).equals(
    fs.readFileSync(path.join(__dirname, 'assets/LUCIDE-LICENSE.txt'))), 'Unmodified icon license ships');
  assert(fs.readFileSync(path.join(stage, 'GAME-ARTWORK.txt')).equals(
    fs.readFileSync(path.join(__dirname, 'GAME-ARTWORK.txt'))), 'Native artwork notice ships');
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(stage, 'GAME-ICON-SOURCES.json'), 'utf8')), nativeIcons);
  const previousStage = path.join(__dirname, `dist/HD2-AutoReload-0.3.39-test-${language}`);
  if (fs.existsSync(path.join(previousStage, 'manifest.json'))) {
    const previous = JSON.parse(fs.readFileSync(path.join(previousStage, 'manifest.json'), 'utf8'));
    assert.equal(previous.Options.length, 44);
    for (let i = 0; i < previous.Options.length; i++) {
      for (const key of optionIds[i] === 'slow' ? ['Image'] : ['Name', 'Image']) {
        assert.deepEqual(manifest.Options[i][key], previous.Options[i][key],
          'Existing option positions and icons remain unchanged');
      }
      if (definitions[i].toggle) {
        assert.deepEqual(manifest.Options[i].Include,
          previous.Options[i].Include,
          'Direct checkbox preserves the previous ON resource path');
      } else {
        assert.deepEqual(manifest.Options[i].SubOptions.map(variant => variant.Include),
          previous.Options[i].SubOptions.map(variant => variant.Include), 'Existing choice resource paths remain unchanged');
      }
    }
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
      assert(source.includes('reload = 0x3326a70'));
      assert(source.includes('sample.reload_allow_move, sample.reload_source = allow == 1, source'));
      assert(source.includes('action == "release-fire"'));
      assert(source.includes('policy:released_fire(now)'));
      assert(source.includes('sample.charge_limit = kind == "epoch" and full or over'));
      assert(source.includes('sample.charge_kind == "epoch" and 1 or 0.9'));
      assert(source.includes('binding.start_mode == "toggle"'));
      assert(source.includes('INPUT toggle-close-replayed vk='));
      assert(source.includes('INPUT toggle-close-release-synced vk='));
      assert(source.includes('INPUT toggle-close-observed vk='));
      assert(source.includes(`local VERSION = "${version}"`));
      assert(source.includes('start_feature("stratagem", function()'));
      assert(source.includes('start_feature("autoreload", function()'));
      assert(source.indexOf('start_feature("stratagem", function()') < source.indexOf('start_feature("autoreload", function()'));
      assert(source.includes('charge90 = setting("charge90", false)'));
      assert(source.includes('radial = option("radial", false), hotkeys = option("hotkeys", false)'));
      assert(source.includes('local fire_pressed = fire and not state.fire'));
      assert(source.includes('OVERLAY click center'));
      assert(source.includes('OVERLAY right-click cancel'));
      assert(source.includes('local right_pressed = right and not state.right'));
      assert(source.includes('not fire and not right then\n            -- Keep capture'));
      assert(source.includes('HD2StratagemHotkeys'));
      assert(source.includes('state.mouse_release or native_active'));
      assert(source.includes('INPUT mouse-release-replayed'));
      assert(source.includes('node >= 1048576 or seen[node]'));
      assert(source.includes('sr.Gui.bitmap_uv(icon.gui, data.material'));
      assert(source.includes('shared_visible(include_shared, kind)'));
      assert(source.includes('local all = bulk("shared_mission_all")'));
      assert(source.includes('local visibility = {other = visible("shared", option("shared_other", false))}'));
      assert(!source.includes('option("shared", false)'), 'Retired master toggle cannot override individual choices');
      for (const filter of filters) assert(source.includes(`{id = "${filter.id}", group = "${filter.id.startsWith('mission_') ? 'mission' : 'shared'}", kinds = {${filter.kinds.join(', ')}}}`));
      assert(!source.includes('node >= capacity'));
      assert(!/WriteProcessMemory|VirtualProtect|set_resource_override/.test(source));
      assert(!source.includes('-- @'));
      for (const marker of ['TankProbe', 'SelfProbe', 'CatalogProbe', 'UnitLinkProbe',
        'HashTypeProbe', 'HASH_TYPE', 'TANK_PROBE', 'sample_legacy', 'autoreload_option_']) {
        assert(!source.includes(marker), 'Removed feature shipped: ' + marker);
      }
    } else {
      assert.equal(bytes.length, 256);
      const expected = definitions.flatMap(option => option.values.map(value => ({
        folder: `Option_${option.id}_${optionModel.suffix(value)}`, source: `return ${JSON.stringify(value)}\n`
      }))).find(variant => variant.folder === folder);
      assert.equal(source, expected.source);
      assert(bytes.subarray(offset + size).every(value => value === 0));
    }
    archives.set(folder, {id, source});
    for (const suffix of ['.stream', '.gpu_resources']) {
      assert.equal(fs.statSync(file + suffix).size, 0);
    }
  }
  const resourceIds = new Set([archives.get('Core').id]);
  for (const option of manifest.Options) {
    for (const variant of variantsFor(option)) assert(variant.Include.includes('Core'), 'Every checkbox/choice deploys the addon');
    const variants = variantsFor(option).map(variant => archives.get(variant.Include.find(folder => folder !== 'Core')));
    assert(variants.every(variant => variant.id === variants[0].id), 'Exclusive choices set one resource');
    assert.equal(new Set(variants.map(variant => variant.source)).size, variants.length);
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
    const values = selected.map((variant, i) => variant ? JSON.parse(
      archives.get(variant.Include.find(folder => folder !== 'Core')).source.slice('return '.length)) : defaults[i]);
    for (let i = 0; i < selected.length; i++) {
      const variant = selected[i];
      assert.equal(values[i], variant ? definitions[i].values[variantsFor(manifest.Options[i]).indexOf(variant)] : defaults[i]);
      if (definitions[i].toggle) assert.equal(values[i], Boolean(variant), 'Check state alone determines ON/OFF');
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
    for (const variant of [null, ...variantsFor(manifest.Options[at])]) {
      const next = [...selected]; next[at] = variant; deployment(index + 1, next);
    }
  }
  deployment(0, omitted());
  let pairs = 0;
  for (let first = 0; first < optionIds.length; first++) {
    for (let second = first + 1; second < optionIds.length; second++) {
      for (const a of [null, ...variantsFor(manifest.Options[first])]) {
        for (const b of [null, ...variantsFor(manifest.Options[second])]) {
          const selected = omitted(); selected[first] = a; selected[second] = b; checkDeployment(selected);
        }
      }
      pairs += (1 + definitions[first].values.length) * (1 + definitions[second].values.length);
    }
  }
  for (const value of [true, false]) checkDeployment(manifest.Options.map((option, i) =>
    definitions[i].toggle ? value ? option : null :
      option.SubOptions[Math.max(0, definitions[i].values.indexOf(value))]));
  checkDeployment(manifest.Options.map(option => variantsFor(option)[0]));
  assert.equal(combinations, baseIndices.reduce((count, at) => count * (1 + definitions[at].values.length), 1) + pairs + 3);
  console.log(`PASS ${language}: ${optionIds.length} localized controls, ${variantCount} option archives, ${combinations} deployment scenarios`);
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
assert.equal(files.length, 10 + optionIds.length + variantCount * 3);
assert.deepEqual(files, packageFiles(korean.stage));
for (const file of files.filter(file => file !== 'manifest.json')) {
  assert(fs.readFileSync(path.join(english.stage, file)).equals(fs.readFileSync(path.join(korean.stage, file))),
    `Language packages have different payloads: ${file}`);
}
console.log('PASS English/Korean packages: same GUID, option order, defaults, paths and byte-identical payloads');
