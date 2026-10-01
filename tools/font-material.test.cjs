const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const archive = require('../../BingusStratagemHotkeys/tools/archive.cjs');
const {hash64} = require('../../BingusStratagemHotkeys/tools/package.cjs');

const packages = archive.readBundlesIndex(), opened = new Map();
const packageId = '9212d7034dc5d55a';
const metadata = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../assets/stratagem-names-ko.json'), 'utf8'));
const pairs = metadata.fonts;
assert.deepEqual(pairs.map(row => [row.id, row.atlas]), [
  ['e007454455e2d2bb', '8d346dcdd08459d5'], ['fca7631255290a2c', '9ae590aec7c63b1c']]);
const radial = fs.readFileSync(path.resolve(__dirname, '../stratagem/radial.lua'), 'utf8');
for (const font of pairs) for (const value of [font.id, font.atlas, font.material, font.slot]) assert(radial.includes(value));
const read = (offset, size, extension = '') => size ? archive.readPackageRange(opened, packages.get(packageId + extension), offset, size) : Buffer.alloc(0);
try {
  const head = read(0, 72), start = 72 + head.readUInt32LE(4) * 32;
  const toc = read(0, start + head.readUInt32LE(8) * 80), entries = new Map();
  for (let i = 0; i < toc.readUInt32LE(8); i++) {
    const at = start + i * 80;
    entries.set(toc.readBigUInt64LE(at).toString(16), {
      type: toc.readBigUInt64LE(at + 8), main: [Number(toc.readBigUInt64LE(at + 16)), toc.readUInt32LE(at + 56)],
      stream: [Number(toc.readBigUInt64LE(at + 24)), toc.readUInt32LE(at + 60)],
      gpu: [Number(toc.readBigUInt64LE(at + 32)), toc.readUInt32LE(at + 64)]
    });
  }
  for (const id of ['47c50c5fab67ccab', 'c38a65a21fb3e8d0']) {
    const b = read(...entries.get(id).main);
    assert.equal(b.readUInt32LE(64), 1);
    assert.equal(b.readUInt32LE(136), Number(hash64('msdf_texture') >> 32n));
    if (id === 'c38a65a21fb3e8d0') assert.equal(b.readBigUInt64LE(140), 0n, 'Previous stock runtime material had no font atlas bound');
    console.log('material', id, 'msdf_texture', b.readBigUInt64LE(140).toString(16));
  }
  for (const spec of pairs) {
    const font = read(...entries.get(spec.id).main), main = read(...entries.get(spec.atlas).main);
    assert.equal(main.subarray(192, 196).toString(), 'DDS ');
    const width = main.readUInt32LE(208), height = main.readUInt32LE(204);
    assert.equal(font.readFloatLE(20), 1 / width); assert.equal(font.readFloatLE(24), 1 / height);
    assert.equal(spec.slot, (hash64('msdf_texture') >> 32n).toString(16) + '00000000');
    assert.equal(main.readUInt32LE(320), 28, 'Native MSDF atlas is RGBA8');
    const count = font.readUInt32LE(68), keys = font.readUInt32LE(72);
    for (const name of metadata.names) for (const char of name.ko) {
      const index = Array.from({length: count}, (_, i) => font.readUInt32LE(keys + i * 4)).indexOf(char.codePointAt(0));
      assert(index >= 0);
      const at = keys + count * 4 + index * 28;
      const [x, y, w, h] = Array.from({length: 4}, (_, i) => font.readFloatLE(at + i * 4));
      assert(x >= 0 && y >= 0 && w >= 0 && h >= 0 && x + w <= width && y + h <= height, 'Glyph lies in its matching atlas');
    }
  }
  console.log('PASS both native font/atlas pairs, glyph geometry, explicit MSDF slot and unbound-material regression');
  const python = process.argv[2];
  if (python) {
    const fonts = ['e007454455e2d2bb', 'fca7631255290a2c'].map(id => {
      const b = read(...entries.get(id).main), count = b.readUInt32LE(68), keys = b.readUInt32LE(72);
      const rows = [];
      for (const char of '증원중기관총에포크') {
        const index = Array.from({length: count}, (_, i) => b.readUInt32LE(keys + i * 4)).indexOf(char.codePointAt(0));
        assert(index >= 0);
        const at = keys + count * 4 + index * 28;
        rows.push({char, metrics: Array.from({length: 7}, (_, i) => b.readFloatLE(at + i * 4))});
      }
      return {id, rows};
    });
    const output = path.resolve(__dirname, '../dist/font-proof'); fs.mkdirSync(output, {recursive: true});
    for (const id of ['8d346dcdd08459d5', '9ae590aec7c63b1c']) {
      const entry = entries.get(id), main = read(...entry.main);
      const dds = Buffer.concat([main.subarray(192), read(...entry.stream, '.stream'), read(...entry.gpu, '.gpu_resources')]);
      const result = spawnSync(python, ['-c',
        'import io,json,sys; from PIL import Image,ImageDraw; meta=json.loads(sys.argv[1]); im=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert("RGB"); out=Image.new("RGB",(700,180),(32,33,36)); d=ImageDraw.Draw(out);\nfor fi,font in enumerate(meta):\n d.text((10,fi*90+4),font["id"],fill="white"); x=10\n for glyph in font["rows"]:\n  a=glyph["metrics"]; crop=im.crop((round(a[0]),round(a[1]),round(a[0]+a[2]),round(a[1]+a[3]))); mask=Image.new("L",crop.size); mask.putdata([sorted(p)[1] for p in crop.getdata()]); mask=mask.point(lambda v: max(0,min(255,(v-100)*5))).resize((40,48)); out.paste("white",(x,fi*90+30,x+40,fi*90+78),mask); x+=48\nout.save(sys.argv[2])',
        JSON.stringify(fonts), path.join(output, id + '.png')], {input: dds, windowsHide: true, maxBuffer: 1024 * 1024});
      assert.equal(result.status, 0, result.stderr?.toString());
      console.log('preview', path.join(output, id + '.png'));
    }
  }
} finally { for (const bundle of opened.values()) bundle.close(); }
