#!/usr/bin/env bash
# build.sh — produce the EXACT on-chain HongCoin bytecode (runtime + creation)
# from HongCoin.sol via solc + a deterministic helper-swap.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/build"

SOL="$ROOT/HongCoin.sol"
SOLJSON="/tmp/soljson/soljson-v0.3.1+commit.c492d9be.js"
ON_RT="$ROOT/onchain_runtime.hex"
ON_CR="$ROOT/onchain_creation.hex"

# 1) compile to runtime + creation
node -e '
const fs=require("fs");
const solc=require("/tmp/soljson/node_modules/solc");
const soljson=require(process.argv[1]);
const compiler=solc.setupMethods(soljson);
const result=compiler.compile(fs.readFileSync(process.argv[2],"utf8"),1);
const c=result.contracts["MyAdvancedToken"];
fs.writeFileSync("compiled_runtime.hex",c.runtimeBytecode);
fs.writeFileSync("compiled_creation.hex",c.bytecode);
' "$SOLJSON" "$SOL"

# 2) swap the string-loop helper to the end of the runtime
python3 "$ROOT/swap_helper.py" compiled_runtime.hex matched_runtime.hex

# 3) build full creation = init || swapped runtime || onchain ctor args
python3 - <<'PY'
co = bytes.fromhex(open('compiled_creation.hex').read().strip())
rt_compiled = bytes.fromhex(open('compiled_runtime.hex').read().strip())
rt_swapped  = bytes.fromhex(open('matched_runtime.hex').read().strip())
oc = bytes.fromhex(open('../onchain_creation.hex').read().strip())

INIT_LEN = co.find(rt_compiled)
assert INIT_LEN >= 0, 'compiled runtime not found in compiled creation'
init = co[:INIT_LEN]
ctor_args = oc[INIT_LEN + len(rt_compiled):]

new_creation = init + rt_swapped + ctor_args
open('matched_creation.hex','w').write(new_creation.hex())
PY

# 4) verify
python3 - <<'PY'
import hashlib
on_rt = open('../onchain_runtime.hex').read().strip()
on_cr = open('../onchain_creation.hex').read().strip()
my_rt = open('matched_runtime.hex').read().strip()
my_cr = open('matched_creation.hex').read().strip()
ok = True
if my_rt == on_rt:
    print('✅ runtime  EXACT MATCH ', f'(sha256: {hashlib.sha256(bytes.fromhex(my_rt)).hexdigest()})')
else:
    print('❌ runtime mismatch'); ok=False
if my_cr == on_cr:
    print('✅ creation EXACT MATCH ', f'(sha256: {hashlib.sha256(bytes.fromhex(my_cr)).hexdigest()})')
else:
    print('❌ creation mismatch'); ok=False
import sys
sys.exit(0 if ok else 1)
PY
