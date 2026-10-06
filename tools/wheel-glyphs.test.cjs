const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const zlib = require('node:zlib');
const sharp = require('sharp');
const {hash64} = require('../../BingusStratagemHotkeys/tools/package.cjs');
const {metadata} = require('./wheel-texture.cjs');

const root = path.resolve(__dirname, '..');
(async () => {
  const m = metadata(), names = JSON.parse(fs.readFileSync(path.join(root, 'assets/stratagem-names-ko.json'), 'utf8'));
  assert.equal(m.fontSha256, '6bcb2a0703aa137e874fc2dffa85f6c21ba9a67fa329e81b8c801663af7e992a');
  assert.equal(m.baseSize, 64); assert.equal(m.license, 'SIL Open Font License 1.1');
  const png = await sharp(path.join(root, 'assets/wheel-glyphs.png')).raw().toBuffer({resolveWithObject: true});
  assert.equal(png.info.width, m.width); assert.equal(png.info.height, m.height);
  const gpu = zlib.gunzipSync(fs.readFileSync(path.join(root, 'assets/wheel-glyphs.rgba.gz')));
  assert(gpu.subarray(0, png.data.length).equals(png.data), 'DDS base level is exactly the generated mask, no MSDF assumptions');
  let expected = 0;
  for (let w = m.width, h = m.height;; w = Math.max(1, w >> 1), h = Math.max(1, h >> 1)) {
    expected += w * h * 4; if (w === 1 && h === 1) break;
  }
  assert.equal(gpu.length, expected, 'Exact native mipmap chain size');
  for (let at = 0; at < gpu.length; at += 4) {
    assert.equal(gpu[at + 1], 0); assert.equal(gpu[at + 2], 0); assert.equal(gpu[at + 3], 255);
  }
  for (const text of [...names.names.map(row => row.ko), '스트라타젬 150']) for (const char of text) {
    const g = m.glyphs[char]; assert(g, `Glyph coverage: ${char}`);
    assert.equal(g.length, 7); assert(g.every(Number.isFinite));
    const [x, y, w, h, , , advance] = g;
    assert(x >= 0 && y >= 0 && x + w <= m.width && y + h <= m.height && advance > 0);
    if (char !== ' ') {
      let bright = 0;
      for (let py = y; py < y + h; py++) for (let px = x; px < x + w; px++) bright += gpu[(py * m.width + px) * 4] > 128;
      assert(bright > 0, `Every glyph has real visible pixels: ${char}`);
    }
  }
  for (const language of ['en', 'ko']) {
    const stage = path.join(root, `dist/HD2-AutoReload-0.3.50-test-${language}`), name = 'Core/9ba626afa44a3aa3.patch_56';
    const bytes = fs.readFileSync(path.join(stage, name)), offset = Number(bytes.readBigUInt64LE(120));
    assert.equal(bytes.readBigUInt64LE(104), hash64(m.resource)); assert.equal(bytes.readBigUInt64LE(112), hash64('texture'));
    assert.equal(bytes.readUInt32LE(160), 340); assert.equal(bytes.readUInt32LE(168), gpu.length);
    assert.equal(bytes.readBigUInt64LE(136), 0n, 'GPU payload begins at zero');
    assert.equal(bytes.readUInt32LE(100), 64); assert.equal(bytes.readUInt32LE(176), 64); assert.equal(bytes.readUInt32LE(180), 1);
    const texture = bytes.subarray(offset, offset + 340), dds = texture.subarray(192);
    assert.equal(texture.readUInt32LE(8), 0xffffffff); assert(texture.subarray(12, 192).every(value => value === 0));
    assert.equal(dds.subarray(0, 4).toString(), 'DDS '); assert.equal(dds.subarray(84, 88).toString(), 'DX10');
    assert.equal(dds.readUInt32LE(12), m.height); assert.equal(dds.readUInt32LE(16), m.width);
    assert.equal(dds.readUInt32LE(128), 28); assert.equal(dds.readUInt32LE(132), 3); assert.equal(dds.readUInt32LE(140), 1);
    assert(fs.readFileSync(path.join(stage, name + '.gpu_resources')).equals(gpu));
    assert.equal(fs.statSync(path.join(stage, name + '.stream')).size, 0);
    assert(fs.readFileSync(path.join(stage, 'WHEEL-FONT-LICENSE.txt')).equals(fs.readFileSync(path.join(root, 'assets/WHEEL-FONT-LICENSE.txt'))));
    const source = JSON.parse(fs.readFileSync(path.join(stage, 'WHEEL-FONT-SOURCES.json'), 'utf8'));
    assert.equal(source.copyright, m.copyright); assert(!source.glyphs);
  }
  console.log(`PASS ${Object.keys(m.glyphs).length} raster glyphs, all 149 Korean labels, real pixels, 12 native DDS mipmaps and both packaged texture resources`);
})().catch(error => {console.error(error); process.exitCode = 1;});
