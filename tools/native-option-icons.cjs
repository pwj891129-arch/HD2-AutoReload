const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const sibling = path.resolve(root, '../BingusStratagemHotkeys');
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function definitions(image, settings, filters) {
  const base = Number(image.readBigUInt64LE(0x348e8f8));
  const vector = offset => Array.from({length: 4}, (_, component) => image.readFloatLE(offset + component * 4));
  return Object.fromEntries(filters.map(filter => [filter.id, filter.kinds.map(kind => {
    const offset = Number(image.readBigUInt64LE(0x37cb600 + kind * 8)) - base;
    assert(offset >= 0 && offset + 400 <= settings.length);
    const nameOffset = Number(settings.readBigUInt64LE(offset + 16)) - base;
    const end = settings.indexOf(0, nameOffset);
    assert(nameOffset >= 0 && end > nameOffset && end - nameOffset < 256);
    const palette = settings.readUInt32LE(offset + 184);
    assert(palette <= 4);
    const colors = [vector(0x331b610 + palette * 16), vector(0x21e89e0), vector(0x21e8a10)];
    assert(colors.flat().every(value => Number.isFinite(value) && value >= 0 && value <= 1));
    return {kind, name: settings.subarray(nameOffset, end).toString(),
      picture: settings.readBigUInt64LE(offset + 176).toString(16).padStart(16, '0'), palette, colors};
  })]));
}

function textures(packages, opened, archive, hash64) {
  const packageId = '6a3eecfddce28fe8';
  const parts = packages.get(packageId);
  assert(parts?.length, 'Native UI texture package required');
  const first = parts[0];
  const filename = path.join(archive.gameData, `bundles.${String(first.bundleIndex).padStart(2, '0')}.nxa`);
  if (!opened.has(filename)) opened.set(filename, archive.readChunks(filename));
  const toc = opened.get(filename).resource(first.bundleOffset);
  assert.equal(toc.readUInt32LE(0), 0xf0000011);
  const start = 72 + 32 * toc.readUInt32LE(4), entries = new Map();
  for (let index = 0; index < toc.readUInt32LE(8); index++) {
    const at = start + 80 * index;
    assert(at + 80 <= toc.length);
    if (toc.readBigUInt64LE(at + 8) !== hash64('texture')) continue;
    entries.set(toc.readBigUInt64LE(at).toString(16).padStart(16, '0'), {
      main: [Number(toc.readBigUInt64LE(at + 16)), toc.readUInt32LE(at + 56)],
      stream: [Number(toc.readBigUInt64LE(at + 24)), toc.readUInt32LE(at + 60)],
      gpu: [Number(toc.readBigUInt64LE(at + 32)), toc.readUInt32LE(at + 64)]
    });
  }
  return picture => {
    const entry = entries.get(picture); assert(entry, `Missing native texture: ${picture}`);
    const partsOf = (section, extension) => {
      const [offset, size] = entry[section];
      if (!size) return Buffer.alloc(0);
      const source = packages.get(packageId + extension); assert(source);
      return archive.readPackageRange(opened, source, offset, size);
    };
    const main = partsOf('main', '');
    assert(main.length >= 340 && main.subarray(192, 196).toString() === 'DDS ');
    const dds = Buffer.concat([main.subarray(192), partsOf('stream', '.stream'), partsOf('gpu', '.gpu_resources')]);
    const width = dds.readUInt32LE(16), height = dds.readUInt32LE(12);
    assert(width >= 32 && width <= 1024 && height >= 32 && height <= 1024);
    assert.equal(dds.readUInt32LE(140), 1, 'One native icon layer only');
    return dds;
  };
}

function decode(dds, python) {
  const result = spawnSync(python, ['-c',
    'import io,struct,sys; from PIL import Image; im=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert("RGBA"); sys.stdout.buffer.write(struct.pack("<II",*im.size)+im.tobytes())'],
  {input: dds, maxBuffer: 8 * 1024 * 1024, windowsHide: true});
  if (result.error) throw result.error;
  assert.equal(result.status, 0, result.stderr?.toString());
  const width = result.stdout.readUInt32LE(0), height = result.stdout.readUInt32LE(4);
  assert.equal(result.stdout.length, 8 + width * height * 4);
  return {pixels: result.stdout.subarray(8), width, height};
}

function coloredMask(mask, colors) {
  const pixels = Buffer.alloc(mask.length);
  for (let at = 0; at < mask.length; at += 4) {
    const weights = colors.map((color, channel) => mask[at + channel] / 255 * color[0]);
    const alpha = weights.reduce((sum, value) => sum + value, 0);
    if (!alpha || !mask[at + 3]) continue;
    // Native palette vectors are ARGB; the RGB texture channels select each color.
    for (let component = 0; component < 3; component++) {
      pixels[at + component] = Math.round(Math.min(1,
        colors.reduce((sum, color, channel) => sum + weights[channel] * color[component + 1], 0) / alpha) * 255);
    }
    pixels[at + 3] = Math.round(Math.min(1, alpha) * mask[at + 3]);
  }
  return pixels;
}

async function main() {
  const {hash64} = require(path.join(sibling, 'tools/package.cjs'));
  const archive = require(path.join(sibling, 'tools/archive.cjs'));
  const python = process.argv[2]; assert(python, 'Pass a Python executable with Pillow DDS support');
  const capture = path.join(sibling, 'scratch');
  const image = fs.readFileSync(path.join(capture, 'game-module.bin'));
  const settings = fs.readFileSync(path.join(capture, 'stratagem-settings.bin'));
  const gameDll = fs.readFileSync(path.resolve(root, '../data/game/game.dll'));
  assert.equal(digest(gameDll), '2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e',
    'Captured native layout must match the installed game');
  const filters = JSON.parse(fs.readFileSync(path.join(root, 'stratagem-filters.json'), 'utf8'));
  const records = definitions(image, settings, filters), packages = archive.readBundlesIndex();
  const opened = new Map(), cache = new Map(), icons = {};
  const output = path.join(root, 'assets/option-icons');
  try {
    const texture = textures(packages, opened, archive, hash64);
    for (const filter of filters) {
      const variants = records[filter.id];
      const native = variants.find(variant => variant.picture !== '0000000000000000');
      if (!native) {
        icons[filter.id] = {source: 'fallback', reason: 'native-definition-has-no-icon', variants,
          pngSha256: digest(fs.readFileSync(path.join(output, filter.id + '.png')))};
        continue;
      }
      if (!cache.has(native.picture)) {
        const dds = texture(native.picture);
        cache.set(native.picture, {ddsSha256: digest(dds), ...decode(dds, python)});
      }
      const mask = cache.get(native.picture);
      const art = await sharp(coloredMask(mask.pixels, native.colors),
        {raw: {width: mask.width, height: mask.height, channels: 4}})
        .resize(208, 208, {fit: 'contain'}).png().toBuffer();
      const png = await sharp({create: {width: 256, height: 256, channels: 4, background: '#202124'}})
        .composite([{input: art, left: 24, top: 24}]).png({compressionLevel: 9}).toBuffer();
      fs.writeFileSync(path.join(output, filter.id + '.png'), png);
      icons[filter.id] = {source: 'game', kind: native.kind, picture: native.picture, palette: native.palette,
        colors: native.colors, width: mask.width, height: mask.height,
        ddsSha256: mask.ddsSha256, pngSha256: digest(png), variants};
    }
  } finally { for (const bundle of opened.values()) bundle.close(); }
  fs.writeFileSync(path.join(root, 'assets/native-option-icons.json'), JSON.stringify({
    source: 'Helldivers 2 installed UI textures and pinned native stratagem definitions',
    gameDllSha256: digest(gameDll), captureSha256: digest(image), settingsSha256: digest(settings),
    texturePackage: '6a3eecfddce28fe8', icons
  }, null, 2) + '\n');
  console.log(`Converted ${Object.values(icons).filter(icon => icon.source === 'game').length} native option previews; ` +
    `${Object.values(icons).filter(icon => icon.source === 'fallback').length} unassigned native icons retain explicit fallbacks`);
}
module.exports = {definitions, textures, coloredMask, decode};
if (require.main === module) main().catch(error => {console.error(error); process.exitCode = 1;});
