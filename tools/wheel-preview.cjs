const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const {definitions, textures, coloredMask, decode} = require('./native-option-icons.cjs');
const archive = require('../../BingusStratagemHotkeys/tools/archive.cjs');
const {hash64} = require('../../BingusStratagemHotkeys/tools/package.cjs');

(async () => {
  const root = path.resolve(__dirname, '..'), preview = JSON.parse(fs.readFileSync(path.join(root, 'dist/wheel-preview.json'), 'utf8'));
  const m = JSON.parse(fs.readFileSync(path.join(root, 'assets/wheel-glyphs.json'), 'utf8'));
  const glyphs = fs.readFileSync(path.join(root, 'assets/wheel-glyphs.png'));
  const capture = path.resolve(root, '../BingusStratagemHotkeys/scratch');
  const records = definitions(fs.readFileSync(path.join(capture, 'game-module.bin')), fs.readFileSync(path.join(capture, 'stratagem-settings.bin')),
    preview.rows.map(row => ({id: row.kind, kinds: [row.kind]})));
  const packages = archive.readBundlesIndex(), opened = new Map();
  const image = textures(packages, opened, archive, hash64), overlays = [], polygons = [];
  const tint = c => `rgb(${c[1]},${c[2]},${c[3]})`;
  const point = p => `${p.x},${preview.height - p.z}`;
  try {
    for (const call of preview.calls) {
      const a = call.args;
      if (call.kind === 'triangle') {
        polygons.push(`<polygon points="${a.slice(0, 3).map(point).join(' ')}" fill="${tint(a[4])}" opacity="${a[4][0] / 255}"/>`);
      } else if (call.kind === 'glyph') {
        const [, lo, hi, p, size, c] = a;
        const crop = await sharp(glyphs).extract({left: Math.round(lo.x * m.width), top: Math.round(lo.y * m.height),
          width: Math.round((hi.x - lo.x) * m.width), height: Math.round((hi.y - lo.y) * m.height)}).raw().toBuffer({resolveWithObject: true});
        for (let at = 0; at < crop.data.length; at += 4) {
          crop.data[at + 3] = Math.round(crop.data[at] * c[0] / 255);
          crop.data[at] = c[1]; crop.data[at + 1] = c[2]; crop.data[at + 2] = c[3];
        }
        overlays.push({input: await sharp(crop.data, {raw: crop.info}).resize(Math.max(1, Math.round(size.x)), Math.max(1, Math.round(size.y))).png().toBuffer(),
          left: Math.round(p.x), top: Math.round(preview.height - p.y - size.y)});
      } else if (call.kind === 'icon') {
        const [index, x, y, size, color] = a, row = preview.rows[index - 1], spec = records[row.kind][0];
        const mask = decode(image(spec.picture), process.argv[2]);
        overlays.push({input: await sharp(coloredMask(mask.pixels, spec.colors), {raw: {width: mask.width, height: mask.height, channels: 4}})
          .resize(Math.round(size), Math.round(size)).modulate({brightness: color[0] / 255}).png().toBuffer(),
          left: Math.round(x - size / 2), top: Math.round(preview.height - y - size / 2)});
      } else if (call.kind === 'text') {
        const [text, , size, , p, c] = a;
        overlays.push({input: Buffer.from(`<svg width="${Math.ceil(text.length * size)}" height="${Math.ceil(size * 1.3)}"><text x="0" y="${size}" font-family="Arial" font-size="${size}" fill="${tint(c)}">${text}</text></svg>`),
          left: Math.round(p.x), top: Math.round(preview.height - p.y - size)});
      }
    }
    assert(preview.calls.filter(call => call.kind === 'glyph').length > 40, 'Real Korean glyphs, not debug-font placeholders');
    const background = Buffer.from(`<svg width="${preview.width}" height="${preview.height}"><rect width="100%" height="100%" fill="#454b40"/>${polygons.join('')}</svg>`);
    const output = path.join(root, 'dist/wheel-preview.png');
    await sharp(background).composite(overlays).png().toFile(output);
    console.log('Preview:', output);
  } finally { for (const bundle of opened.values()) bundle.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
