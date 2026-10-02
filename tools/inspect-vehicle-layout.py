"""Disassemble an existing offline capture only; never access or execute game memory."""
from pathlib import Path
import sys
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

capture = Path(__file__).resolve().parents[2] / 'BingusStratagemHotkeys/scratch/game-module.bin'
image = capture.read_bytes()
at, size = int(sys.argv[1], 0), int(sys.argv[2], 0)
assert 0 <= at < len(image) and 0 < size <= 0x10000 and at+size <= len(image)
dis = Cs(CS_ARCH_X86, CS_MODE_64)
for instruction in dis.disasm(image[at:at+size], at):
    print(f'{instruction.address:08x} {instruction.bytes.hex():24s} {instruction.mnemonic} {instruction.op_str}')
