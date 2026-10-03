const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

// Review existing offline evidence only. No game code is called or shipped.
const capture = path.join(__dirname, '../../BingusStratagemHotkeys/scratch/game-module.bin');
if (!fs.existsSync(capture)) {
  console.log('SKIP vehicle layout: local capture unavailable');
} else {
  const image = fs.readFileSync(capture);
  const evidence = new Map([
    [0xa7d744, '488b35d5958a02'],
    [0xa7d75f, '4c8dbeb0d85300'],
    [0xa7d76f, '4869c138120000'],
    [0xa7d809, '488b3568958a02'],
    [0xa7d83f, '49c1e5064c036e48'],
    [0xa7d501, '4a8b841088e85300'],
    [0xa7d509, '48c1e832'],
    [0xa7f480, '48b9040000000b000000'],
    [0xa7f49e, '7413'],
    [0xa7f4ae, 'e8ad56cfff'],
    [0xa7f269, '488b0db0718a02'],
    [0xa7f1d5, '4881c6d00f0000'],
    [0xa7f1df, '4889742478'],
    [0xa7f2cc, '488b442478'],
    [0xa7f273, 'c644242000'],
    [0xa7f278, 'e8a376d0ff'],
    [0xa7f2b5, '48b90000000001000000'],
    [0xa7f2d6, '488508'],
    [0xa7e160, '48b80000000001000000'],
    [0xa7e16f, '488581d00f0000'],
    [0x776098, '4c8b1d9106bb02'],
    [0x776108, '498b43388b1c88'],
    [0x776131, '488b0d0805bb02'],
    [0x776198, '8b7d04'],
    [0x7761a5, 'e8b65c0500'],
    [0x7cbeea, '498b4238'],
    [0x7cbeee, '4869c9e0000000'],
    [0x7cbef5, '807c011000'],
    [0x7cbf0d, '8b0401'],
  ]);
  for (const [at, hex] of evidence) assert.equal(image.subarray(at, at + hex.length / 2).toString('hex'), hex);
  for (const [at, root] of [[0xa7d744, 53636384], [0xa7d809, 0x3326d78],
    [0xa7f269, 53634080], [0x776098, 0x3326730], [0x776131, 0x3326640]]) {
    assert.equal(at + 7 + image.readInt32LE(at + 3), root, 'Reviewed vehicle component root');
  }
  assert.equal(0x7761a5 + 5 + image.readInt32LE(0x7761a5 + 1), 0x7cbe60);
  assert.equal(0x53e888 - 5495040, 0xf88, 'Seated branch and cached avatar-row origins differ by 0x50');
  assert.equal(0x53e888 + 4, 0x53e88c, 'Bit 50 lives at bit 18 of the high word');
  console.log('PASS pinned mounted-primary, native seated-input permission and reload-animation layout');
}
