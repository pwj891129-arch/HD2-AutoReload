const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const sharp = require('sharp');

async function main() {
  const folder = path.resolve(__dirname, '../assets/option-icons');
  const files = fs.readdirSync(folder).sort();
  assert.equal(files.length, 45);
  const filters = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../stratagem-filters.json'), 'utf8'));
  const provenance = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../assets/native-option-icons.json'), 'utf8'));
  const native = provenance.icons, hashes = new Map();
  assert.deepEqual(Object.keys(native), filters.map(filter => filter.id));
  assert.equal(Object.values(native).filter(icon => icon.source === 'game').length, 23);
  assert.equal(Object.values(native).filter(icon => icon.source === 'fallback').length, 11);
  for (const file of files) {
    assert(/^[a-z0-9_]+\.png$/.test(file));
    const bytes = fs.readFileSync(path.join(folder, file));
    const id = file.slice(0, -4), reference = native[id];
    const hash = crypto.createHash('sha256').update(bytes).digest('hex');
    if (reference) {
      assert.equal(hash, reference.pngSha256, 'PNG matches the native/fallback source record');
      assert.deepEqual(reference.variants.map(variant => variant.kind), filters.find(filter => filter.id === id).kinds);
      if (reference.source === 'game') {
        assert(/^[0-9a-f]{16}$/.test(reference.picture) && reference.picture !== '0000000000000000');
        const selected = reference.variants.find(variant => variant.kind === reference.kind);
        assert.equal(reference.picture, selected.picture);
        assert.deepEqual(reference.colors, selected.colors);
        assert.equal(reference.palette, selected.palette);
        assert(/^[0-9a-f]{64}$/.test(reference.ddsSha256));
      } else {
        assert.equal(reference.reason, 'native-definition-has-no-icon');
        assert(reference.variants.every(variant => variant.picture === '0000000000000000'));
      }
    }
    const {data, info} = await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject: true});
    assert.equal(info.width, 256); assert.equal(info.height, 256); assert.equal(info.channels, 4);
    let visible = 0;
    for (let at = 0; at < data.length; at += 4) {
      assert.equal(data[at + 3], 255, 'Opaque contrast plate works on either app theme');
      if (data[at] > 100 || data[at + 1] > 100 || data[at + 2] > 100) visible++;
    }
    assert(visible > 3000 && visible < 40000, `Nonblank, framed glyph: ${file}`);
    const small = await sharp(bytes).resize(32, 32).removeAlpha().raw().toBuffer();
    assert(small.some(value => value > 180), 'Readable bright glyph at thumbnail size');
    if (hashes.has(hash)) {
      const previous = native[hashes.get(hash)];
      assert.equal(reference?.source, 'game', 'Only native duplicates are allowed');
      assert.equal(previous?.source, 'game');
      assert.equal(reference.picture, previous.picture, 'Shared PNGs must come from the same native texture');
      assert.deepEqual(reference.colors, previous.colors, 'Shared PNGs must use the same native palette');
    } else hashes.set(hash, id);
  }
  const {coloredMask, definitions} = require('./native-option-icons.cjs');
  const colors = [[1, 1, 0, 0], [0.5, 0, 1, 0], [0.2, 0, 0, 1]];
  const mask = Buffer.from([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 255, 255, 0, 0, 0]);
  assert.deepEqual([...coloredMask(mask, colors)], [255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 51,
    0, 0, 0, 0, 0, 0, 0, 0], 'Mask channels, ARGB vectors, coverage and transparency');
  const capture = path.resolve(__dirname, '../../BingusStratagemHotkeys/scratch');
  if (fs.existsSync(path.join(capture, 'game-module.bin')) && fs.existsSync(path.join(capture, 'stratagem-settings.bin'))) {
    const image = fs.readFileSync(path.join(capture, 'game-module.bin'));
    const settings = fs.readFileSync(path.join(capture, 'stratagem-settings.bin'));
    assert.equal(crypto.createHash('sha256').update(image).digest('hex'), provenance.captureSha256);
    assert.equal(crypto.createHash('sha256').update(settings).digest('hex'), provenance.settingsSha256);
    for (const [id, variants] of Object.entries(definitions(image, settings, filters))) {
      assert.deepEqual(native[id].variants, variants, 'Preview identities/palettes match actual captured game definitions');
    }
    console.log('PASS pinned native reference: all 34 option kinds, texture identities and palettes');
  } else console.log('SKIP pinned native reference: local captures unavailable');
  console.log(`PASS 45 previews (${hashes.size} distinct): 23 native, 11 documented fallbacks, 11 settings; pixels, contrast and thumbnail downscaling`);
}
main().catch(error => {console.error(error); process.exitCode = 1;});
