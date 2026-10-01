const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const zlib = require('node:zlib');

const root = path.resolve(__dirname, '..');
const metadata = () => JSON.parse(fs.readFileSync(path.join(root, 'assets/wheel-glyphs.json'), 'utf8'));
function lua(hash64) {
  const m = metadata();
  return 'return {\n    texture = "' + hash64(m.resource).toString(16) + '", base = ' + m.baseSize +
    ', width = ' + m.width + ', height = ' + m.height + ',\n    glyphs = {\n' +
    Object.entries(m.glyphs).map(([char, metrics]) => `        [${JSON.stringify(char)}] = {${metrics.join(', ')}},`).join('\n') +
    '\n    },\n}\n';
}
function pack(folder, hash64, template) {
  const pixels = zlib.gunzipSync(fs.readFileSync(path.join(root, 'assets/wheel-glyphs.rgba.gz')));
  const m = metadata(), main = Buffer.alloc(340);
  // HD2SDK StingrayTexture.Serialize: 12-byte header, 15 empty mip rows, DX10 DDS.
  main.writeUInt32LE(0xffffffff, 8);
  const dds = main.subarray(192);
  dds.write('DDS '); dds.writeUInt32LE(124, 4); dds.writeUInt32LE(0x2100f, 8);
  dds.writeUInt32LE(m.height, 12); dds.writeUInt32LE(m.width, 16); dds.writeUInt32LE(m.width * 4, 20);
  const levels = Math.floor(Math.log2(Math.max(m.width, m.height))) + 1;
  dds.writeUInt32LE(levels, 28); dds.writeUInt32LE(32, 76); dds.writeUInt32LE(4, 80); dds.write('DX10', 84);
  dds.writeUInt32LE(0x401008, 108); dds.writeUInt32LE(28, 128); // RGBA8 UNORM, not sRGB.
  dds.writeUInt32LE(3, 132); dds.writeUInt32LE(1, 140);
  assert(pixels.length > m.width * m.height * 4);
  // Reuse the parent builder's one-resource header, as its option markers do.
  assert(template.length >= 192);
  const bytes = Buffer.alloc(Math.ceil((192 + main.length) / 16) * 16);
  template.copy(bytes, 0, 0, 192);
  bytes.writeBigUInt64LE(BigInt(bytes.length), 32);
  bytes.writeBigUInt64LE(hash64('texture'), 80);
  const at = 104;
  bytes.writeBigUInt64LE(hash64(m.resource), at); bytes.writeBigUInt64LE(hash64('texture'), at + 8);
  bytes.writeBigUInt64LE(192n, at + 16); bytes.writeUInt32LE(main.length, at + 56);
  bytes.writeUInt32LE(pixels.length, at + 64);
  bytes.writeUInt32LE(64, 100); bytes.writeUInt32LE(64, at + 72); bytes.writeUInt32LE(1, at + 76);
  main.copy(bytes, 192);
  const file = path.join(folder, '9ba626afa44a3aa3.patch_56');
  fs.writeFileSync(file, bytes);
  fs.writeFileSync(file + '.stream', Buffer.alloc(0));
  fs.writeFileSync(file + '.gpu_resources', pixels);
}
module.exports = {lua, pack, metadata};
if (require.main === module) {
  const sharp = require('sharp');
  (async () => {
    const m = metadata(), images = [];
    const source = fs.readFileSync(path.join(root, 'assets/wheel-glyphs.png'));
    for (let w = m.width, h = m.height;; w = Math.max(1, w >> 1), h = Math.max(1, h >> 1)) {
      // Coverage is the red mask; opaque alpha avoids multiplying edge coverage twice.
      const red = await sharp(source).removeAlpha().extractChannel(0).resize(w, h, {kernel: 'linear'}).raw().toBuffer();
      const pixels = Buffer.alloc(w * h * 4);
      for (let i = 0; i < red.length; i++) { pixels[i * 4] = red[i]; pixels[i * 4 + 3] = 255; }
      images.push(pixels);
      if (w === 1 && h === 1) break;
    }
    const output = path.join(root, 'dist'); fs.mkdirSync(output, {recursive: true});
    fs.writeFileSync(path.join(output, 'wheel-glyphs.rgba'), Buffer.concat(images));
    fs.writeFileSync(path.join(root, 'assets/wheel-glyphs.rgba.gz'), zlib.gzipSync(Buffer.concat(images), {level: 9, mtime: 0}));
    console.log(`Built ${images.length} coverage mipmaps, ${Buffer.concat(images).length} GPU bytes`);
  })().catch(error => {console.error(error); process.exitCode = 1;});
}
