# ERC-8063 Reference Implementation

Reference implementation of **[ERC-8063: Groups — Membership Tokens](https://ercs.ethereum.org/ERCS/erc-8063)**.

Authored by [Cheng Qian](https://github.com/deakee) — sole author of ERC-8063, ERC-7743, and ERC-7837.

---

## What is ERC-8063?

ERC-8063 defines a token model where **balance = membership level**. Any ERC-20 token can be a Group — the standard adds a single optional introspection method (`isMember`) that lets any contract check whether an address holds at least a given threshold of tokens.

This turns token holdings into a portable, composable membership primitive:

- Hold ≥ 100 tokens → access tier 1
- Hold ≥ 1,000 tokens → access tier 2
- Hold ≥ 10,000 tokens → access tier 3

No separate registry, no soulbound restrictions, no custom access lists. Just a balance check.

**Full spec:** https://ercs.ethereum.org/ERCS/erc-8063

---

## Files

| File | Description |
|---|---|
| `IERC8063.sol` | The interface — the single `isMember(address, uint256)` method |
| `ERC8063.sol` | Minimal reference implementation (ERC-20 + IERC8063 + mint/burn) |

---

## Interface

```solidity
interface IERC8063 {
    /// @notice Returns true if `account` holds at least `threshold` tokens
    function isMember(address account, uint256 threshold) external view returns (bool);
}
```

`isMember(account, threshold)` is equivalent to `balanceOf(account) >= threshold`. The interface exists so any contract can detect and use this pattern without importing ERC-20 logic.

---

## Usage

### Check membership in another contract

```solidity
import "./IERC8063.sol";

contract MyCouponGate {
    IERC8063 public membershipToken;
    uint256 public requiredBalance;

    constructor(address token, uint256 threshold) {
        membershipToken = IERC8063(token);
        requiredBalance = threshold;
    }

    modifier onlyMembers() {
        require(membershipToken.isMember(msg.sender, requiredBalance), "Not a member");
        _;
    }

    function claimCoupon() external onlyMembers {
        // only addresses holding >= requiredBalance tokens can call this
    }
}
```

### Deploy a new Group (membership token)

```solidity
ERC8063 token = new ERC8063(
    "My Group",   // name
    "GRP",        // symbol
    18,           // decimals
    0             // initial supply (0 = start empty, mint manually)
);

token.mint(alice, 1000e18);  // alice now holds 1000 tokens → member at any threshold ≤ 1000
```

---

## Live deployment

Deakee is the first production application built on ERC-8063. The DKG token implements ERC-8063 — member tier is determined by DKG balance, and partner coupon access is gated by `isMember` calls.

- **App:** https://deakee.com (iOS, Android, Web)
- **GitHub org:** https://github.com/deakee

---

## License

CC0-1.0 — no rights reserved. Use freely.
