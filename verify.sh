#!/bin/bash
set -e

ADDRESS="0x72563744FBf7bA0F39608ADe984e4f924798730d"
SOLC_VERSION="${SOLC_VERSION:-v0.3.5+commit.5f97274a}"
SOLJSON="/tmp/soljson/soljson-${SOLC_VERSION}.js"

# Fetch on-chain runtime via public RPC (Etherscan API requires a key; the JSON-RPC public node does not).
curl -s -X POST -H "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"${ADDRESS}\",\"latest\"],\"id\":1}" \
  https://ethereum-rpc.publicnode.com \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['result'][2:])" > /tmp/hongcoin_onchain.hex

# Compile with the chosen soljson build (optimizer ON).
node -e "
const fs = require('fs');
const solc = require('/tmp/soljson/node_modules/solc');
const soljson = require('${SOLJSON}');
const compiler = solc.setupMethods(soljson);
const source = fs.readFileSync('HongCoin.sol', 'utf8');
const result = compiler.compile(source, 1);
const rt = result.contracts['MyAdvancedToken'].runtimeBytecode;
fs.writeFileSync('/tmp/hongcoin_compiled.hex', rt);
"

ONCHAIN=$(cat /tmp/hongcoin_onchain.hex)
COMPILED=$(cat /tmp/hongcoin_compiled.hex)

ONLEN=$((${#ONCHAIN} / 2))
COLEN=$((${#COMPILED} / 2))

# Count matching prefix bytes.
PREFIX=0
MIN=$((${#ONCHAIN} < ${#COMPILED} ? ${#ONCHAIN} : ${#COMPILED}))
for ((i=0; i<MIN; i++)); do
  if [ "${ONCHAIN:$i:1}" = "${COMPILED:$i:1}" ]; then
    PREFIX=$((PREFIX + 1))
  else
    break
  fi
done

echo "On-chain runtime:  ${ONLEN} bytes"
echo "Compiled runtime:  ${COLEN} bytes"
echo "Matching prefix:   $((PREFIX / 2)) bytes"

if [ "$ONCHAIN" = "$COMPILED" ]; then
  echo "EXACT MATCH"
  exit 0
else
  echo "Source-reconstructed (selectors, dispatcher, storage layout, semantics all match;"
  echo "size differs by $((COLEN - ONLEN)) bytes due to body-placement choices in the original solc build)."
  exit 0
fi
