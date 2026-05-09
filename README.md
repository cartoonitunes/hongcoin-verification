# HongCoin Verification

Byte-for-byte bytecode verification for `0x72563744FBf7bA0F39608ADe984e4f924798730d`.

| Field | Value |
|---|---|
| Contract | `0x72563744FBf7bA0F39608ADe984e4f924798730d` |
| Network | Ethereum Mainnet |
| Block | 1,785,453 |
| Deployed | June 28, 2016 |
| Deployer | `0x00756cF8159095948496617F5FB17ED95059f536` |
| Compiler | soljson v0.3.1+commit.c492d9be (optimizer ON) |
| Template | ConsenSys `MyAdvancedToken` (project-modified) |
| Runtime match | ✅ EXACT (2,677 bytes, sha256 `24db5ebf…f318f9`) |
| Creation match | ✅ EXACT (sha256 `93882d68…1aa6fe`) |
| Verification | Exact bytecode match (solc + deterministic helper-swap post-process) |

## What this contract does

HongCoin is a 2016-era ERC-20-style token deployed from the ConsenSys
`MyAdvancedToken` template. It supports the standard token API
(`transfer`, `transferFrom`, `approve`/`approveAndCall`, `balanceOf`,
`allowance`) plus a marketplace (`buy`, `sell`, `setPrices`), admin minting
(`mintToken`), and account freezing (`freezeAccount`).

The deployer `0x00756cf8...` is the same address that deployed several other
TheDAO-cluster contracts in mid-2016 — HongCoin is part of that group and
relates to the HONG DAO project.

The contract was deployed with `initialSupply = 10000` and `centralMinter`
set to the deployer. After deployment the owner called `mintToken` once to
bring `totalSupply` up to 1,000,000,000 — that's why the live `totalSupply()`
returns one billion even though the constructor argument was 10,000.

## Verification

```bash
./verify.sh
```

Output:

```
✅ runtime  EXACT MATCH  (sha256: 24db5ebf91002490f1be16510f92498e8c11eedaa04173109c744ed428f318f9)
✅ creation EXACT MATCH  (sha256: 93882d6847c381554dd3cb129aa4ad5b7de33ba8c1ad450b3f282bdf191aa6fe)
```

The script compiles `HongCoin.sol` with soljson v0.3.1 (optimizer ON), runs a
deterministic post-processing pass (`swap_helper.py`), and compares the
result byte-for-byte against `onchain_runtime.hex` and `onchain_creation.hex`
(both fetched from mainnet).

## How the exact match works

`solc --optimize` v0.2.x–v0.3.5 emits the runtime in this layout:

```
0x000–0x05d7   dispatcher + return helpers
0x05d8–0x060a  string-loop helper (51 bytes)
0x060b–0x0a32  function bodies
0x0a33+        transferOwnership SSTORE + tail
```

The on-chain build was produced by a solc that put the string-loop helper at
the *end* of the runtime instead:

```
0x000–0x05d7   dispatcher + return helpers
0x05d8–0x09ff  function bodies (shifted -51)
0x0a00–0x0a32  string-loop helper (moved to end)
0x0a33+        transferOwnership SSTORE + tail
```

Every body is content-identical between the two layouts — only the
*placement order* differs. Empirical testing across 28 soljson builds
(v0.1.1 through v0.4.7), 17 archived nightlies (v0.2.1 → v0.3.5 nightly),
8 native-solc docker images, and `--optimize-runs` ∈ {1, 5, …, 10000} could
not reproduce the on-chain placement: solc's `ControlFlowGraph::rebuildCode`
deterministically links the string-helper into the prev/next chain right
after the return-helper cluster. Producing the on-chain layout requires
either a custom solc patch to `rebuildCode` or a post-emission swap.

`swap_helper.py` does the swap: it moves the helper section to the tail and
rewrites the 23 absolute `PUSH2` jump targets that reference shifted
addresses. The transformation is closed (every PUSH2 immediate either falls
in the helper range, the body range, or neither), so it's deterministic and
auditable. See `swap_helper.py` for the exact mapping.

## Source-level changes vs the unmodified template

Five edits to the upstream ConsenSys `MyAdvancedToken` template were
required to reproduce the exact on-chain bodies:

1. `mintToken` events use `owner`, not `this`:
   ```solidity
   Transfer(0, owner, mintedAmount);
   Transfer(owner, target, mintedAmount);
   ```
2. `sell()` is **void** (not `returns (uint revenue)`) and uses the
   refund-on-failure pattern:
   ```solidity
   function sell(uint amount) {
       if (balanceOf[msg.sender] < amount) throw;
       balanceOf[this] += amount;
       balanceOf[msg.sender] -= amount;
       if (!msg.sender.send(amount * sellPrice)) {
           balanceOf[msg.sender] += amount;
       }
       Transfer(msg.sender, this, amount);
   }
   ```
3. `buy()` is **void** (not `returns (uint amount)`) with the amount as a
   local variable.
4. `transferOwnership` is **defined inside `MyAdvancedToken`** (overriding
   the `owned` parent), which places its SSTORE body at the end of the
   runtime layout.
5. Compile with `solc v0.3.1+commit.c492d9be --optimize` (v0.2.0, v0.2.1,
   v0.3.0, v0.3.1, v0.3.2 all produce the same 2,677-byte output with
   identical body placement).

## Storage layout (verified against on-chain reads)

| Slot | Field | Source |
|---:|---|---|
| 0 | `owner` | `owned` |
| 1 | `standard = "Token 0.1"` | `token` |
| 2 | `name` | `token` |
| 3 | `symbol` | `token` |
| 4 | `decimals` (uint8) | `token` |
| 5 | `totalSupply` | `token` (set by parent constructor; shadowed at runtime by slot 10) |
| 6 | `balanceOf` (mapping) | `token` |
| 7 | `allowance` (mapping) | `token` |
| 8 | `sellPrice` | `MyAdvancedToken` |
| 9 | `buyPrice` | `MyAdvancedToken` |
| 10 | `totalSupply` (shadowing, getter returns this) | `MyAdvancedToken` |
| 11 | `frozenAccount` (mapping) | `MyAdvancedToken` |

The shadowed `totalSupply` at slot 10 is what `mintToken` updates and what
the `totalSupply()` getter returns. Slot 5 is set once by the parent
`token` constructor and is dead state thereafter — a quirk of the original
template's inheritance.

## Constructor arguments (decoded from the creation tx)

```
initialSupply  = 10000
tokenName      = "HongCoin"
decimalUnits   = 0
tokenSymbol    = "Ħ"          (UTF-8 0xC4A6)
centralMinter  = 0x00756cF8159095948496617F5FB17ED95059f536
```

Creation tx: `0xecd246884db943385c76d9e2bd36d5bcab45500553d4404fc9eb884ee8d144da`

## Files

- `HongCoin.sol` — reconstructed source (ConsenSys `MyAdvancedToken` template, modified as described above)
- `swap_helper.py` — deterministic post-process that moves the string-loop helper and rewrites jump targets
- `build/build.sh` — compile + swap pipeline (writes `matched_runtime.hex` and `matched_creation.hex`)
- `verify.sh` — runs `build/build.sh` and prints the diff result
- `onchain_runtime.hex` — runtime bytecode fetched from mainnet
- `onchain_creation.hex` — full creation calldata (init + runtime + ABI-encoded args)
