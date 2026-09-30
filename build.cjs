const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = __dirname;
const version = '0.3.25-test';
const luaType = 0xA14E8DFA2CD117E2n;
const mask = 0xffffffffffffffffn;
const mix = 0xC6A4A7935BD1E995n;
const resource = 'mods/hd2_helper/auto_reload';
const sourceFolder = process.argv[2];
const readSource = file => fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');

function extract(relative, expectedHash) {
  const archive = fs.readFileSync(path.join(sourceFolder, relative));
  assert.equal(crypto.createHash('sha256').update(archive).digest('hex'), expectedHash);
  assert.equal(archive.readUInt32LE(0), 0xf0000011);
  assert.equal(archive.readUInt32LE(8), 1);
  const entry = 72 + 32 * archive.readUInt32LE(4);
  assert.equal(archive.readBigUInt64LE(entry + 8), luaType);
  const offset = Number(archive.readBigUInt64LE(entry + 16));
  const length = archive.readUInt32LE(entry + 56);
  assert.equal(archive.readUInt32LE(offset + 4), 2);
  return archive.subarray(offset + 8, offset + length).toString('utf8');
}
function hash64(value) {
  const data = Buffer.from(value);
  let h = (BigInt(data.length) * mix) & mask;
  let i = 0;
  while (i + 8 <= data.length) {
    let k = (data.readBigUInt64LE(i) * mix) & mask;
    k ^= k >> 47n;
    k = (k * mix) & mask;
    h = ((h ^ k) * mix) & mask;
    i += 8;
  }
  if (i < data.length) {
    let tail = 0n;
    for (let j = i; j < data.length; j++) tail |= BigInt(data[j]) << BigInt((j - i) * 8);
    h = ((h ^ tail) * mix) & mask;
  }
  h ^= h >> 47n;
  h = (h * mix) & mask;
  return h ^ (h >> 47n);
}
const common = sourceFolder && extract('COMMON/9ba626afa44a3aa3.patch_0',
  'f4736d958f0228ab955dcb20cdfd7be65d8089df672b0ec8524e765d515ca8c5');
let numbers = sourceFolder && extract('NUMBERS_BOTH/9ba626afa44a3aa3.patch_4',
  '9c25cc086aeea9cef03d9be8c0c14e352d156d6f68c5ab5cae161b35b509e420');
const compact = text => text.split('\n').filter(line => line.trim())
  .map(line => line.replace(/[ \t]+$/, '')).join('\n');
const vendor = path.join(root, 'vendor');
let core;
if (sourceFolder) {
const start = common.indexOf('local __module_registry = {}');
const boundary = 'do\nlocal __imports = {}\nlocal __factory = (function()\nreturn function(imports)\n';
const sections = common.slice(start).split(boundary);
const chosen = ['20-identity-core', '30-generated-common', '40-provider'].map(name => {
  const matches = sections.filter(section => section.startsWith(`if type(imports) ~= "table" then error("${name}:`));
  assert.equal(matches.length, 1, `Reader module ${name} boundary changed`);
  return boundary + matches[0];
});
assert(start > 0 && sections[0].startsWith('local __module_registry = {}'));
core = '-- Derived from HD2 HUD+ 0.1.2 by DDRK1NG; see THIRD_PARTY.txt.\n' +
  compact(sections[0] + chosen.join('')) + '\n' +
  'if #__module_errors > 0 then error(table.concat(__module_errors, "; ")) end\nreturn __module_registry\n';
assert(!core.includes('__original_boot') && !core.includes('90-main'));
fs.mkdirSync(vendor, { recursive: true });
fs.writeFileSync(path.join(vendor, 'reader_core.lua'), core);
fs.writeFileSync(path.join(vendor, 'numbers.lua'), compact(numbers));
const hooks = sections.filter(section => section.startsWith('if type(imports) ~= "table" then error("00-boot-state:'));
assert.equal(hooks.length, 1, 'HUD callback test module boundary changed');
fs.writeFileSync(path.join(vendor, 'hud_hooks_reference.lua'),
  '-- Test-only callback reference derived from HD2 HUD+ 0.1.2 by DDRK1NG.\n' +
  compact(sections[0] + boundary + hooks[0]) + '\nreturn __module_registry.BootState\n');
fs.copyFileSync(path.join(sourceFolder, 'README.txt'), path.join(vendor, 'HD2-HUD-0.1.2-original-README.txt'));
} else {
  core = readSource(path.join(vendor, 'reader_core.lua'));
  numbers = readSource(path.join(vendor, 'numbers.lua'));
}
const source = readSource(path.join(root, 'addon.lua'))
  .replace('-- @OPTIONS@', () => readSource(path.join(root, 'options.lua')))
  .replace('-- @POLICY@', () => readSource(path.join(root, 'policy.lua')))
  .replace('-- @NATIVE@', () => readSource(path.join(root, 'native.lua')))
  .replace('-- @NATIVE_READER@', () => readSource(path.join(root, 'native_reader.lua')))
  .replace('-- @TANK_PROBE@', () => readSource(path.join(root, 'tank_probe.lua')))
  .replace('-- @SELF_PROBE@', () => readSource(path.join(root, 'self_probe.lua')))
  .replace('-- @CATALOG_PROBE@', () => readSource(path.join(root, 'catalog_probe.lua')))
  .replace('-- @UNIT_LINK_PROBE@', () => readSource(path.join(root, 'unit_link_probe.lua')))
  .replace('-- @HASH_TYPE_PROBE@', () => readSource(path.join(root, 'hash_type_probe.lua')))
  .replace('-- @READER_CORE@', () => core)
  .replace('-- @NUMBERS@', () => compact(numbers));
assert.equal(source.split('\n')[0], `-- HD2-Addon: ${resource}`);
assert(!source.includes('00-boot-state') && !source.includes('90-main'), 'HUD test reference must not ship');
const stage = path.join(root, 'dist', `HD2-AutoReload-${version}`);
fs.mkdirSync(path.join(stage, 'Addon'), { recursive: true });
fs.writeFileSync(path.join(root, 'dist', 'auto_reload.generated.lua'), source);
fs.writeFileSync(path.join(root, 'dist', 'reader_core.lua'), core);
fs.writeFileSync(path.join(root, 'dist', 'numbers.lua'), compact(numbers));
fs.copyFileSync(path.join(vendor, 'HD2-HUD-0.1.2-original-README.txt'), path.join(stage, 'HD2-HUD-0.1.2-original-README.txt'));
for (const file of ['README.md', 'THIRD_PARTY.txt']) fs.copyFileSync(path.join(root, file), path.join(stage, file));
const lua = Buffer.from(source, 'utf8');
const payload = Buffer.alloc(lua.length + 8);
payload.writeUInt32LE(lua.length, 0);
payload.writeUInt32LE(2, 4);
lua.copy(payload, 8);
const offset = 192;
const archive = Buffer.alloc(offset + Math.ceil(payload.length / 16) * 16);
archive.writeUInt32LE(0xf0000011, 0);
archive.writeUInt32LE(1, 4);
archive.writeUInt32LE(1, 8);
archive.writeBigUInt64LE(BigInt(archive.length), 32);
archive.writeBigUInt64LE(luaType, 80);
archive.writeUInt32LE(1, 88);
archive.writeUInt32LE(16, 96);
archive.writeUInt32LE(16, 100);
archive.writeBigUInt64LE(hash64(resource), 104);
archive.writeBigUInt64LE(luaType, 112);
archive.writeBigUInt64LE(BigInt(offset), 120);
archive.writeUInt32LE(payload.length, 160);
archive.writeUInt32LE(16, 172);
archive.writeUInt32LE(16, 176);
payload.copy(archive, offset);
const filename = '9ba626afa44a3aa3.patch_0';
fs.writeFileSync(path.join(stage, 'Addon', filename), archive);
for (const suffix of ['.stream', '.gpu_resources']) fs.writeFileSync(path.join(stage, 'Addon', filename + suffix), Buffer.alloc(0));
const description = `Auto reload ${version}. Requires Bingus Shared Loader v15+ / API 1. ` +
  'Checks ammunition exhaustion, actual weapon swaps, and fire attempts. All personal weapons use a build-pinned, read-only held-object component reader at 50 ms intervals. Ambiguous readings, underbarrel, and vehicle weapons remain excluded. Live testing required.';
const options = [
  ['enabled', '자동재장전 ON/OFF', '체크하면 자동재장전 활성화, 미체크하면 모드를 실행하지 않습니다.', ['Addon']],
  ['ammo_off', '실탄 무기 자동재장전 OFF', '체크하면 실탄 무기의 자동재장전을 끕니다. 미체크하면 기존 동작을 유지합니다.', []],
  ['heat_off', '과열 무기 자동재장전 OFF', '체크하면 과열 무기의 자동재장전을 끕니다. 미체크하면 완전 과열시에만 작동합니다.', []],
  ['diagnostics', 'F9 진단 활성화', '체크시에만 F9 읽기 전용 진단을 실행합니다. 일반 자동재장전에는 필요하지 않습니다.', []],
];
const optionManifest = options.map(([name, label, help, include], index) => {
  const folder = 'Option_' + name;
  const bytes = Buffer.from('return true\n'), module = Buffer.alloc(8 + bytes.length);
  module.writeUInt32LE(bytes.length, 0); module.writeUInt32LE(2, 4); bytes.copy(module, 8);
  const marker = Buffer.alloc(192 + Math.ceil(module.length / 16) * 16);
  archive.copy(marker, 0, 0, 192);
  marker.writeBigUInt64LE(BigInt(marker.length), 32);
  marker.writeBigUInt64LE(hash64('mods/hd2_helper/autoreload_option_' + name), 104);
  marker.writeUInt32LE(module.length, 160); module.copy(marker, 192);
  fs.mkdirSync(path.join(stage, folder), {recursive: true});
  const patch = `9ba626afa44a3aa3.patch_${index + 1}`;
  fs.writeFileSync(path.join(stage, folder, patch), marker);
  for (const suffix of ['.stream', '.gpu_resources']) fs.writeFileSync(path.join(stage, folder, patch + suffix), Buffer.alloc(0));
  return {Name: label, Description: help, Include: [...include, folder]};
});
fs.writeFileSync(path.join(stage, 'manifest.json'), JSON.stringify({
  Version: 1, Guid: '9d720fab-718f-4c91-93c5-31c4c3e6c42e', Name: `HD2 Helper Auto Reload ${version}`,
  Description: description + ' Feature options are configured in Arsenal only; Purge / Deploy and restart to apply.', Options: optionManifest
}, null, 2));
const report = { version, resource, resourceHash: hash64(resource).toString(16),
  archiveBytes: archive.length, sourceBytes: lua.length, stage,
  archiveSha256: crypto.createHash('sha256').update(archive).digest('hex') };
fs.writeFileSync(path.join(root, 'dist', 'build-report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
