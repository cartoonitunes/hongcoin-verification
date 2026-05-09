#!/bin/bash
# verify.sh — wrapper around build/build.sh for byte-for-byte verification.
# Compiles HongCoin.sol with soljson v0.3.1, applies the deterministic
# helper-swap post-process, and compares against the on-chain runtime
# and creation bytecode in onchain_*.hex.
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SOLC_VERSION="${SOLC_VERSION:-v0.3.1+commit.c492d9be}"
SOLJSON="/tmp/soljson/soljson-${SOLC_VERSION}.js"

# Sanity: soljson available
if [ ! -f "$SOLJSON" ]; then
  echo "Missing soljson at $SOLJSON"
  echo "Download with: mkdir -p /tmp/soljson && cd /tmp/soljson && \\"
  echo "  curl -sSLo soljson-${SOLC_VERSION}.js https://binaries.soliditylang.org/bin/soljson-${SOLC_VERSION}.js && \\"
  echo "  npm init -y >/dev/null && npm i solc@0.3.1 >/dev/null"
  exit 1
fi

bash "$ROOT/build/build.sh"
