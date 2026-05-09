# HongCoin Verification

Source-reconstructed verification for `0x72563744FBf7bA0F39608ADe984e4f924798730d`.

| Field | Value |
|---|---|
| Contract | `0x72563744FBf7bA0F39608ADe984e4f924798730d` |
| Network | Ethereum Mainnet |
| Block | 1,785,453 |
| Deployed | June 28, 2016 |
| Deployer | `0x00756cF8159095948496617F5FB17ED95059f536` |
| Compiler | soljson v0.3.x (optimizer ON) |
| Template | ConsenSys `MyAdvancedToken` |
| Name | HongCoin |
| Symbol | Ħ |
| Decimals | 0 |
| Initial supply | 10,000 |
| totalSupply (post-mint) | 1,000,000,000 |
| Verification | Source-reconstructed (selectors + storage layout + dispatcher byte-exact; runtime body placement differs by 82 bytes from the original solc build) |

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

## Verification

```bash
./verify.sh
```

The script fetches the live runtime bytecode via a public Ethereum JSON-RPC
endpoint and compiles `HongCoin.sol` with soljson v0.3.5 (optimizer ON),
then compares.

**Result:** all 20 function selectors, the full dispatcher prologue (first
256 bytes byte-exact), and every storage slot match the on-chain contract.
The compiled runtime is 82 bytes shorter than on-chain because the original
solc build placed certain function bodies (notably `transferOwnership`)
later in the layout — a layout-only difference that is not behaviour-visible.
This is published as `source_reconstructed` rather than `verified` for that
reason.

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

- `HongCoin.sol` — reconstructed source (ConsenSys `MyAdvancedToken` template)
- `onchain_runtime.hex` — runtime bytecode fetched from mainnet
- `onchain_creation.hex` — full creation calldata (init + runtime + ABI-encoded args)
- `verify.sh` — reproducible compile-and-compare script
