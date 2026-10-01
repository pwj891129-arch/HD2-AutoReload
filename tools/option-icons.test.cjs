const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const sharp = require('sharp');

async function main() {
  const folder = path.resolve(__dirname, '../assets/option-icons');
  const files = fs.readdirSync(folder).sort();
  assert.equal(files.length, 41);
  const hashes = new Set();
  for (const file of files) {
    assert(/^[a-z0-9_]+\.png$/.test(file));
    const bytes = fs.readFileSync(path.join(folder, file));
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
    hashes.add(crypto.createHash('sha256').update(bytes).digest('hex'));
  }
  assert.equal(hashes.size, files.length, 'Each option has a distinct preview');
  console.log('PASS 41 unique previews: dimensions, nonblank pixels, contrast and thumbnail downscaling');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
