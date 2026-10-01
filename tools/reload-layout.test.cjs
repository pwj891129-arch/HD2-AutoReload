const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

// Offline evidence only. Captured game bytes are never shipped or executed.
const capture = path.join(__dirname, '../../BingusStratagemHotkeys/scratch/game-module.bin');
if (fs.existsSync(capture)) {
  const image = fs.readFileSync(capture);
  const evidence = new Map([
    [0x7759a7, '488b3d3a12bb02'],
    [0x73b4e0, '498b4530498b0c044885c975074c89742478eb0d488b09e864bddbff'],
    [0x73b509, 'e8b2e72600'],
    [0x73b51a, '4c8b3dc7b0be02'],
    [0x73b594, 'e87771dcff488bb0880000004885ed'],
    [0x73b5ab, 'e84072180083f811'],
    [0x73b623, '498b4f508bd78b40143904d10f827bfeffff'],
    [0x9a9cdb, '4c8b1d56ca9702'],
    [0x9a9d5e, '488d0c40498b43504803c98b4cc80c890aebc8'],
    [0x4f7280, '48f7e148c1ea038d0452c1e002442bc0'],
    [0x508e9f, '4c8b90c02bf100'],
    [0x509352, '4869c0e800000049038390000000'],
    [0x8c288f, 'e81c6ac4ff8b8080000000'],
    [0x7787bf, '488b1daae2ba02'],
    [0x4fd25b, '458b4b68418b5b700fafd8'],
    [0x4fd2c2, '488d048048c1e004490383a000000048'],
    [0x4fce2f, '4c8b900028f100'],
    [0x4fce47, '69c2f2010000'],
    [0x4fcea1, '488d048948c1e0044805201f00004903c2'],
    [0x77567c, 'e89f7bd8ff4c8b25a810bb024c8bf88b1d8fe5d002488944244044386801'],
  ]);
  for (const [rva, hex] of evidence) {
    assert.equal(image.subarray(rva, rva + hex.length / 2).toString('hex'), hex,
      `Pinned native reload instruction at 0x${rva.toString(16)}`);
  }
  assert.equal(0x7787bf + 7 + image.readInt32LE(0x7787bf + 3), 0x3326a70,
    'Reload manager global matches native RIP-relative access');
  assert.equal(0x77567c + 5 + image.readInt32LE(0x77567c + 1), 0x4fd220,
    'Native movement check calls the inspected reload config resolver');
  for (const [at, target] of [[0x7759a7, 0x3326be8], [0x73b51a, 0x33265e8], [0x9a9cdb, 0x3326738]]) {
    assert.equal(at + 7 + image.readInt32LE(at + 3), target, 'Native backpack manager global');
  }
  console.log('PASS pinned reload layout: movement, self-assisted backpack check, equipped slot, deposit count and support class');
} else console.log('SKIP pinned reload layout: local capture unavailable');

let low = 0x33333333, high = 0x44444444;
for (let i = 0; i < 10000; i++) {
  low = (Math.imul(low, 1664525) + 1013904223) >>> 0;
  high = (Math.imul(high, 1664525) + 1013904223) >>> 0;
  for (const capacity of [12, 58, 498, 688]) {
    const actual = ((high % capacity) * (4294967296 % capacity) + low % capacity) % capacity;
    const expected = Number(((BigInt(high) << 32n) | BigInt(low)) % BigInt(capacity));
    assert.equal(actual, expected, 'Lossless unsigned type-hash modulo without Lua uint64 rounding');
  }
}
console.log('PASS 40000 unsigned reload/backpack-registry hash checks');
