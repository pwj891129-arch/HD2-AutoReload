const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const capture = path.resolve(__dirname, '../../BingusStratagemHotkeys/scratch/game-module.bin');
if (fs.existsSync(capture)) {
  const image = fs.readFileSync(capture);
  const evidence = new Map([
    [0x66cb38, '448b707c'],
    [0x66cd78, 'e8c3ccf6ff'],
    [0x5d9b37, '4969c478100000'],
    [0x5d9b54, '418b08'],
    [0x5d9b5f, '8b517c'],
    [0x5d9b98, '410fb67808'],
    [0x5d9c58, '4380bc2e3501000000'],
    [0x5d9c61, 'f3430f10bc2e40010000'],
    [0x5d9d40, '4380bc2e3401000000'],
    [0x5d9e80, '4380bc2e3601000000'],
    [0x4fa901, '4869c1d00a0000'],
    [0x4fa8a7, '69c2b2010000'],
    [0x4fa8e4, '3db1010000'],
    [0x4fa8ed, '4181f9b2010000'],
    [0x6f25f9, '418b4f0c'],
    [0x6f26a3, 'c6472601'],
  ]);
  for (const [rva, hex] of evidence) assert.equal(image.subarray(rva, rva + hex.length / 2).toString('hex'), hex,
    `Pinned mission location instruction at 0x${rva.toString(16)}`);
  console.log('PASS native mission location evidence: stage, anchors, radii and Discovery');
} else console.log('SKIP native mission location evidence: capture unavailable');

for (let i = 0; i < 10000; i++) {
  const low = (Math.imul(i + 1, 1664525) + 1013904223) >>> 0;
  const high = (Math.imul(i + 2, 22695477) + 1) >>> 0;
  const actual = ((high % 434) * (4294967296 % 434) + low % 434) % 434;
  assert.equal(actual, Number(((BigInt(high) << 32n) | BigInt(low)) % 434n));
}
assert.equal(434 * 16, 0x1b20, 'Native bucket count matches record origin');
assert.equal(Number(0x3aade0806542af22n % 434n), 148, 'Live flag objective native hash bucket');
console.log('PASS 10000 unsigned mission definition hash checks and live flag bucket');
