const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

// Offline evidence only. Captured game bytes are never shipped or executed.
const capture = path.join(__dirname, '../../BingusStratagemHotkeys/scratch/game-module.bin');
if (fs.existsSync(capture)) {
  const image = fs.readFileSync(capture);
  const evidence = new Map([
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
  console.log('PASS pinned reload layout: manager, instance/authored resolver and movement byte');
} else console.log('SKIP pinned reload layout: local capture unavailable');

let low = 0x33333333, high = 0x44444444;
for (let i = 0; i < 10000; i++) {
  low = (Math.imul(low, 1664525) + 1013904223) >>> 0;
  high = (Math.imul(high, 1664525) + 1013904223) >>> 0;
  const actual = ((high % 498) * (4294967296 % 498) + low % 498) % 498;
  const expected = Number(((BigInt(high) << 32n) | BigInt(low)) % 498n);
  assert.equal(actual, expected, 'Lossless unsigned type-hash modulo without Lua uint64 rounding');
}
console.log('PASS 10000 unsigned reload-registry hash checks');
