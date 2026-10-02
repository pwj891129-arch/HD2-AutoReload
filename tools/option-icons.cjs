const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'assets', 'option-icons');
const sourceFile = path.join(root, 'assets', 'option-icon-vectors.json');
const symbols = {
  enabled: 'RefreshCw', charge90: 'Gauge', radial: 'CircleDot', hotkeys: 'Keyboard',
  shared_other: 'LayoutGrid', scale: 'Maximize2', slow: 'Timer',
  shared_reinforce: 'UserPlus', shared_sos: 'RadioTower', shared_resupply: 'Package',
  mission_flare: 'Sun', mission_extraction: 'LogOut', mission_flag: 'Flag',
  mission_bug_thumper: 'AudioLines', mission_seismic: 'Waves', mission_seaf: 'Crosshair',
  mission_dark_fluid: 'Droplets', mission_oil_rig: 'Fuel', mission_hellbomb: 'Bomb',
  mission_data_jack: 'Cable', mission_tcs: 'SprayCan', mission_prospecting: 'Pickaxe',
  mission_cargo: 'Container', mission_bug_plug: 'Ban', mission_cyborg_data: 'Bot',
  mission_camera: 'Camera', mission_carry_data: 'Database', mission_pinata: 'RadioReceiver',
  mission_explosives: 'Radio', mission_poison_drill: 'Biohazard', mission_emergency: 'Siren',
  mission_comms: 'Satellite', mission_carpet_bomb: 'Plane', mission_scrambler: 'Unplug',
  mission_immediate: 'AlarmClock', mission_seaf_squad: 'Users', mission_spire: 'TestTubeDiagonal',
  mission_destroyer: 'Ship', mission_discovery: 'Upload', mission_drilling_charge: 'Drill',
  mission_nuke: 'Radiation',
  shared_all: 'Layers', mission_all: 'ListChecks', shared_mission_all: 'Combine', vehicle: 'Truck'
};

function importVectors(asar) {
  if (asar.endsWith('.js')) return saveVectors(fs.readFileSync(asar, 'utf8'));
  const fd = fs.openSync(asar, 'r');
  let library;
  try {
    const header = Buffer.alloc(16);
    assert.equal(fs.readSync(fd, header, 0, 16, 0), 16);
    const jsonSize = header.readUInt32LE(12);
    assert(jsonSize > 0 && jsonSize < 16 * 1024 * 1024);
    const json = Buffer.alloc(jsonSize);
    assert.equal(fs.readSync(fd, json, 0, jsonSize, 16), jsonSize);
    let entry = JSON.parse(json.toString());
    for (const name of 'obfuscated_src/renderer/@cdn/lucide.min.js'.split('/')) entry = entry.files[name];
    assert(entry.size > 0 && entry.size < 1024 * 1024);
    const bytes = Buffer.alloc(entry.size);
    assert.equal(fs.readSync(fd, bytes, 0, bytes.length, 8 + header.readUInt32LE(4) + Number(entry.offset)), bytes.length);
    library = bytes.toString();
  } finally { fs.closeSync(fd); }
  saveVectors(library);
}
function saveVectors(library) {
  assert(library.includes('@license lucide v0.544.0 - ISC'), 'Pinned Lucide version required');
  const exports = {};
  vm.runInNewContext(library, {exports, module: {exports}}, {timeout: 2000});
  const icons = {};
  for (const [id, name] of Object.entries(symbols)) {
    assert(Array.isArray(exports[name]) && exports[name].length > 0, `Missing Lucide symbol: ${name}`);
    icons[id] = {symbol: name, nodes: exports[name]};
  }
  fs.mkdirSync(path.dirname(sourceFile), {recursive: true});
  fs.writeFileSync(sourceFile, JSON.stringify({source: 'Lucide 0.544.0', icons}, null, 2) + '\n');
}

function color(id) {
  if (id.startsWith('shared_')) return '#f4d44c';
  if (id.startsWith('mission_')) return '#7edbb5';
  return '#79d0ec';
}
function svg(id, nodes) {
  const shapes = nodes.map(([tag, attrs]) => {
    assert(['path', 'circle', 'line', 'polyline', 'polygon', 'rect', 'ellipse'].includes(tag));
    const attributes = Object.entries(attrs).map(([key, value]) => {
      assert(/^[a-z][a-z0-9-]*$/i.test(key));
      assert(!/[<>&"]/.test(String(value)));
      return `${key}="${value}"`;
    }).join(' ');
    return `<${tag} ${attributes}/>`;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 32 32">` +
    `<rect width="32" height="32" fill="#202124"/>` +
    `<g transform="translate(4 4)" fill="none" stroke="${color(id)}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${shapes}</g></svg>`;
}
async function main() {
  if (process.argv[2] === '--import') importVectors(process.argv[3]);
  const source = JSON.parse(fs.readFileSync(sourceFile, 'utf8'));
  assert.equal(source.source, 'Lucide 0.544.0');
  assert.deepEqual(Object.keys(source.icons), Object.keys(symbols));
  fs.mkdirSync(output, {recursive: true});
  const nativeFile = path.join(root, 'assets', 'native-option-icons.json');
  const native = fs.existsSync(nativeFile) ? JSON.parse(fs.readFileSync(nativeFile, 'utf8')).icons : {};
  const rows = [];
  for (const [id, icon] of Object.entries(source.icons)) {
    assert.equal(icon.symbol, symbols[id]);
    const image = native[id]?.source === 'game' ? fs.readFileSync(path.join(output, id + '.png')) :
      Buffer.from(svg(id, icon.nodes));
    if (native[id]?.source !== 'game') await sharp(image).png({compressionLevel: 9}).toFile(path.join(output, id + '.png'));
    const index = rows.length;
    rows.push({input: await sharp(image).resize(96, 96).png().toBuffer(),
      left: (index % 8) * 104 + 4, top: Math.floor(index / 8) * 104 + 4});
  }
  fs.mkdirSync(path.join(root, 'dist'), {recursive: true});
  await sharp({create: {width: 832, height: Math.ceil(rows.length / 8) * 104,
    channels: 4, background: '#151515'}}).composite(rows).png()
    .toFile(path.join(root, 'dist', 'option-icons-contact.png'));
  console.log(`Checked ${rows.length} Arsenal-only PNG previews; assigned native icons preserved`);
}
main().catch(error => {console.error(error); process.exitCode = 1;});
