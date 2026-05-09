#!/usr/bin/env python3
"""
swap_helper.py — post-process solc output to move the string-loop helper
from the [0x05d8, 0x060b) region to the end of the runtime, just before
the transferOwnership SSTORE block. This produces the exact on-chain layout.

Invariants used:
- Solc emits the contract dispatcher + return helpers at 0x000-0x05d7.
- Solc then emits the string-loop helper (51 bytes) at 0x05d8-0x060a.
- Solc then emits the function bodies at 0x060b-0xa32.
- The transferOwnership SSTORE follows at 0xa33.
- The helper is referenced only by absolute PUSH2 jumps; rewriting them to
  the new positions is a closed transformation.

The on-chain wants:
- 0x000-0x05d7: dispatcher + return helpers (unchanged)
- 0x05d8-0x09ff: function bodies (shifted -51)
- 0x0a00-0x0a32: string-loop helper (moved to end)
- 0x0a33+: transferOwnership SSTORE + metadata (unchanged)

Two address-shift mappings:
- A in [0x05d8, 0x060b): helper. New address = A - 0x05d8 + 0x0a00 = A + 0x428
- A in [0x060b, 0x0a33): bodies.  New address = A - 0x060b + 0x05d8 = A - 0x33
"""
import sys

def main():
    src_path = sys.argv[1]
    out_path = sys.argv[2]

    src = bytes.fromhex(open(src_path).read().strip())
    HELPER_START_OLD = 0x05d8
    HELPER_END_OLD = 0x060b
    BODIES_START_OLD = 0x060b
    BODIES_END_OLD = 0x0a33
    HELPER_LEN = HELPER_END_OLD - HELPER_START_OLD  # 51 bytes
    BODIES_LEN = BODIES_END_OLD - BODIES_START_OLD  # 1064 bytes

    # New positions
    HELPER_START_NEW = BODIES_START_OLD + (BODIES_LEN - HELPER_LEN) - 0  # 0x05d8 + 1064 - 0 = 0x0a00
    # i.e. helper now at 0x0a00; bodies now at 0x05d8

    def remap(a: int) -> int:
        if HELPER_START_OLD <= a < HELPER_END_OLD:
            return a - HELPER_START_OLD + 0x0a00
        if BODIES_START_OLD <= a < BODIES_END_OLD:
            return a - 0x33
        return a

    # First, build new bytecode with sections swapped
    helper = src[HELPER_START_OLD:HELPER_END_OLD]
    bodies = src[BODIES_START_OLD:BODIES_END_OLD]

    new = bytearray()
    new += src[:HELPER_START_OLD]              # 0x000-0x05d7
    new += bodies                               # 0x05d8 - 0x09ff (bodies move up)
    new += helper                               # 0x0a00 - 0x0a32 (helper moves to end)
    new += src[BODIES_END_OLD:]                 # 0x0a33+ (transferOwnership + tail)

    assert len(new) == len(src), f'len mismatch: {len(new)} vs {len(src)}'

    # Now rewrite all PUSH2 immediates that reference shifted addresses.
    # Walk instructions to find PUSH2.
    i = 0
    rewritten = []
    while i < len(new):
        op = new[i]
        if op == 0x61:  # PUSH2
            old_arg = (new[i+1] << 8) | new[i+2]
            new_arg = remap(old_arg)
            if new_arg != old_arg:
                new[i+1] = (new_arg >> 8) & 0xff
                new[i+2] = new_arg & 0xff
                rewritten.append((i, old_arg, new_arg))
            i += 3
        elif 0x60 <= op < 0x80:  # PUSH1..PUSH32
            push_size = op - 0x5f
            i += 1 + push_size
        else:
            i += 1

    print(f'rewrote {len(rewritten)} PUSH2 instructions')

    open(out_path, 'w').write(new.hex())
    print(f'wrote {out_path}')

if __name__ == '__main__':
    main()
