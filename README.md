# ERC-8063 Reference Implementation

[![ci](https://github.com/deakee/erc-8063-reference/actions/workflows/test.yml/badge.svg)](https://github.com/deakee/erc-8063-reference/actions)
[![License: CC0-1.0](https://img.shields.io/badge/License-CC0-blue.svg)](./LICENSE)
[![ERC-8063](https://img.shields.io/badge/ERC-8063-purple)](https://ercs.ethereum.org/ERCS/erc-8063)

Production-ready reference implementation of **[ERC-8063: Groups — Membership Tokens](https://ercs.ethereum.org/ERCS/erc-8063)**, the standard that turns any ERC-20 balance into a portable, composable membership primitive.

Authored by [@jamesavechives](https://github.com/jamesavechives) (Cheng Qian) — sole author of [ERC-7743](https://eips.ethereum.org/EIPS/eip-7743), [ERC-7837](https://ercs.ethereum.org/ERCS/erc-7837), and [ERC-8063](https://ercs.ethereum.org/ERCS/erc-8063).

This is the **first production implementation** of ERC-8063 — the same contracts that power [Deakee](https://deakee.com)'s cross-brand loyalty network.

---

## What is ERC-8063?

ERC-8063 defines a token model where **balance = membership level**. Any ERC-20 token can be a Group — the standard adds a single optional introspection method (`isMember`) that lets any contract check whether an address holds at least a given threshold of tokens.

```solidity
interface IERC8063 {
    function isMember(address account, uint256 threshold) external view returns (bool);
}
```

That's the entire spec.

### Why this matters

Most membership / loyalty / access systems require:
- A separate registry contract per service
- Bespoke allowlists / soulbound tokens
- Bilateral integration deals between issuers and consumers

ERC-8063 collapses all of that into a **balance check**. Any contract anywhere can ask any ERC-20 token "does this address hold ≥ N of you?" — and gate behavior accordingly.

**Result**: composable membership across the entire EVM, with zero integration overhead. Hold 100 tokens at brand A → unlock tier 1 at brand A, brand B, brand C, anywhere that decided to recognize you. No deals required.

---

## Use cases (see `examples/`)

The library ships with three reference patterns showing what you can build:

### [`GroupGate`](./examples/GroupGate.sol) — restrict function access by membership
The simplest possible application. Inherit, set a group + threshold, and use the `onlyMember` modifier to gate any function.

```solidity
contract PremiumFeature is GroupGate {
    constructor() GroupGate(0xGroupTokenAddress, 100 ether) {}

    function premiumAction() external onlyMember {
        // Only callable by accounts holding ≥ 100 tokens of the group
    }
}
```

### [`TieredDiscount`](./examples/TieredDiscount.sol) — multi-tier loyalty pricing
The Deakee use case in concrete form: different discount levels based on Group token balance.

```solidity
// Tier 1:    100 tokens →  5% off
// Tier 2:  1,000 tokens → 10% off
// Tier 3: 10,000 tokens → 20% off
TieredDiscount discount = new TieredDiscount(groupToken, tiers);

uint16 bps = discount.effectiveDiscountBps(buyer);        // best tier they qualify for
uint256 price = discount.discountedPrice(buyer, 100e18);  // apply it to a list price
```

### [`CrossGroupBundle`](./examples/CrossGroupBundle.sol) — require multiple groups
The interesting composition: a reward that needs membership in BOTH brand A AND brand B. Demonstrates how ERC-8063 composes trivially (AND/OR balance checks) where soulbound or allowlist systems would require complex per-pair plumbing.

---

## Quickstart

### Use the contracts in your project

```bash
# Foundry
forge install deakee/erc-8063-reference

# In your Solidity:
import "erc-8063-reference/src/IERC8063.sol";
import "erc-8063-reference/examples/GroupGate.sol";
```

### Run the tests

```bash
git clone https://github.com/deakee/erc-8063-reference
cd erc-8063-reference
forge install foundry-rs/forge-std --no-commit
forge test -vv
```

Expected: all tests pass (40+ tests across `test/ERC8063.t.sol` and `test/Examples.t.sol`, including fuzz tests).

### Deploy your own Group

```bash
# Deploy a 1M-supply Group token to a testnet
forge create src/ERC8063.sol:ERC8063 \
    --constructor-args "My Community" "MYC" 18 1000000000000000000000000 \
    --rpc-url <YOUR_RPC> \
    --private-key <YOUR_KEY>
```

---

## Repo layout

```
.
├── src/                     # core contracts
│   ├── IERC8063.sol        # the spec interface (single method)
│   └── ERC8063.sol         # minimal reference (ERC-20 + IERC8063 + mint/burn)
├── examples/                # adoption patterns
│   ├── GroupGate.sol       # abstract onlyMember modifier
│   ├── TieredDiscount.sol  # multi-tier loyalty pricing
│   └── CrossGroupBundle.sol # AND/OR composition across groups
├── test/                    # Foundry tests
│   ├── ERC8063.t.sol       # core contract tests
│   └── Examples.t.sol      # example pattern tests
├── foundry.toml             # Foundry config
└── .github/workflows/       # CI
```

---

## Security considerations

This is a **reference implementation**. Use as-is for prototyping; have a separate audit before mainnet deployment of derived contracts.

Known properties:

| Property | Status |
|---|---|
| **No transfer restrictions** | `transfer` / `transferFrom` work like vanilla ERC-20. Membership tier can disappear if the user transfers tokens away. By design. |
| **Owner-only mint** | The reference impl restricts `mint` to the constructor's deployer. Apps that want delegated minting or DAO governance should subclass. |
| **No on-chain history** | `isMember` only checks current balance. No "was a member at time X" — implement with snapshots if you need historical proofs. |
| **Re-entrancy** | All state changes happen before external calls. Standard `transfer` re-entrancy considerations apply (no callback hooks added). |
| **ERC-20 transfer hooks** | Not implemented (kept minimal). If you need them, use OpenZeppelin's ERC-20 with this `isMember` method bolted on — it's one line. |
| **ERC-165 detection** | `supportsInterface(type(IERC8063).interfaceId)` returns true. Use this to discover whether a token participates in the Group ecosystem. |

---

## Authoring lineage

This standard and its sibling standards were authored to enable a class of on-chain primitives that didn't exist before:

| Standard | Status | What it adds |
|---|---|---|
| [**ERC-8063**](https://ercs.ethereum.org/ERCS/erc-8063) | Final | Groups — Membership Tokens (this repo) |
| [**ERC-7743**](https://eips.ethereum.org/EIPS/eip-7743) | Final | Multi-Owner NFTs (shared ownership with provider fees) |
| [**ERC-7837**](https://ercs.ethereum.org/ERCS/erc-7837) | Final | Diffusive Tokens (mint-on-transfer with fee mechanism) |

All three composed together enable [Deakee](https://deakee.com)'s cross-brand loyalty network: members hold partner tokens (ERC-8063), share collectibles (ERC-7743), and the network token itself diffuses on transfer (ERC-7837).

---

## Contributing

Pull requests welcome. Please run `forge test -vv` and `forge fmt --check` before submitting.

For substantive changes (new examples, optimizations, gas improvements), open an issue first so we can discuss whether it belongs in the reference impl or in a downstream library.

---

## License

CC0 1.0 Universal — public domain. See [LICENSE](./LICENSE).

Use these contracts in commercial products, fork them, modify them — attribution appreciated but not required.

---

## Related

- ERC-8063 spec: https://ercs.ethereum.org/ERCS/erc-8063
- Deakee (first production app): https://deakee.com
- Author: https://github.com/jamesavechives
- Foundry docs: https://book.getfoundry.sh/
