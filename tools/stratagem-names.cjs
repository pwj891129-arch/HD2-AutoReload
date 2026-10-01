const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const archive = require('../../BingusStratagemHotkeys/tools/archive.cjs');
const {hash64} = require('../../BingusStratagemHotkeys/tools/package.cjs');

const root = path.resolve(__dirname, '..');
const packages = archive.readBundlesIndex(), opened = new Map();
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const fallback = {
  35: '이글 추가 기총소사', 47: '전차 고폭탄 장전', 60: '전차 캐니스터탄 장전',
  86: '원격 폭발물', 95: '전차 대전차탄 장전', 111: '즉시 탈출 신호기',
  116: 'SEAF 분대', 132: '핵 타격',
};

// Offline installed assets only; never attaches to a game process.
try {
  const parts = packages.get('9ba626afa44a3aa3'), first = parts[0];
  const file = path.join(archive.gameData, `bundles.${String(first.bundleIndex).padStart(2, '0')}.nxa`);
  const bundle = archive.readChunks(file); opened.set(file, bundle);
  const toc = bundle.resource(first.bundleOffset), start = 72 + 32 * toc.readUInt32LE(4);
  const strings = new Map();
  for (let i = 0; i < toc.readUInt32LE(8); i++) {
    const at = start + 80 * i;
    if (toc.readBigUInt64LE(at + 8) !== hash64('strings')) continue;
    const bytes = archive.readPackageRange(opened, parts, Number(toc.readBigUInt64LE(at + 16)), toc.readUInt32LE(at + 56));
    const count = bytes.readUInt32LE(8);
    if (!count || bytes.readUInt32LE(12) !== Number(hash64('ko') >> 32n)) continue;
    assert(16 + count * 8 <= bytes.length);
    for (let j = 0; j < count; j++) {
      const key = bytes.readUInt32LE(16 + j * 4), offset = bytes.readUInt32LE(16 + count * 4 + j * 4);
      const end = bytes.indexOf(0, offset);
      assert(offset >= 16 + count * 8 && end >= offset);
      strings.set(key, bytes.subarray(offset, end).toString('utf8'));
    }
  }
  const capture = path.resolve(root, '../BingusStratagemHotkeys/scratch');
  const image = fs.readFileSync(path.join(capture, 'game-module.bin'));
  const settings = fs.readFileSync(path.join(capture, 'stratagem-settings.bin'));
  const base = Number(image.readBigUInt64LE(0x348e8f8));
  const names = [];
  for (let kind = 1; kind <= 149; kind++) {
    const record = Number(image.readBigUInt64LE(0x37cb600 + kind * 8)) - base;
    assert(record >= 0 && record + 400 <= settings.length);
    const offset = Number(settings.readBigUInt64LE(record + 16)) - base;
    const end = settings.indexOf(0, offset);
    assert(offset >= 0 && end > offset);
    // Native name StringId is already stored in the definition, not rehashed from the debug label.
    const key = [settings.readUInt32LE(record + 44), settings.readUInt32LE(record + 40)]
      .find(value => strings.has(value));
    const text = strings.get(key);
    const ko = (text || fallback[kind] || '').trim();
    assert(ko && !/[\r\n<>]/.test(ko), `Missing or malformed Korean name: ${kind}`);
    names.push({kind, native: settings.subarray(offset, end).toString('utf8'), ko,
      source: text ? 'game' : 'fallback', stringId: text ? key.toString(16).padStart(8, '0') : null});
  }
  const fonts = [
    {id: 'e007454455e2d2bb', offset: 6159696, size: 43704},
    {id: 'fca7631255290a2c', offset: 6203408, size: 50604},
  ].map(spec => {
    const bytes = archive.readPackageRange(opened, packages.get('9212d7034dc5d55a'), spec.offset, spec.size);
    const count = bytes.readUInt32LE(68), offset = bytes.readUInt32LE(72);
    assert(offset === 88 && offset + count * 4 <= bytes.length);
    const glyphs = Array.from({length: count}, (_, i) => bytes.readUInt32LE(offset + i * 4));
    const chars = new Set(glyphs);
    for (const name of names) for (const char of name.ko) assert(chars.has(char.codePointAt(0)), `Font lacks ${char}: ${spec.id}`);
    return {id: spec.id, material: 'content/fonts/runtime_font', sha256: digest(bytes), glyphs};
  });
  const data = {source: 'Installed Korean strings + pinned native stratagem definitions',
    settingsSha256: digest(settings), names, fonts};
  const target = path.join(root, 'assets/stratagem-names-ko.json');
  if (process.argv.includes('--check')) assert.deepEqual(JSON.parse(fs.readFileSync(target, 'utf8')), data,
    'Committed Korean labels and font glyph metadata match offline native assets');
  else fs.writeFileSync(target, JSON.stringify(data, null, 2) + '\n');
  console.log(`PASS Korean names: ${names.length}, game ${names.filter(row => row.source === 'game').length}, fallback ${names.filter(row => row.source === 'fallback').length}; two native fonts cover every label`);
} finally { for (const bundle of opened.values()) bundle.close(); }
