// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../src/IERC8063.sol";

/// @title TieredDiscount — multi-tier loyalty pricing backed by ERC-8063
/// @notice Demonstrates the real Deakee use case: a partner brand offers
///         different discount levels based on Group token balance. No
///         registry, no allowlists — just a balance check at purchase time.
///
/// Configuration example (3 tiers):
///   Tier 1:    100 tokens →  5% off
///   Tier 2:  1,000 tokens → 10% off
///   Tier 3: 10,000 tokens → 20% off
///
/// At checkout, the contract returns the deepest discount the buyer
/// qualifies for. Brands can set arbitrary thresholds + percentages.
///
/// This is what Channel #1 (programmatic-SEO coupon pages) hooks into:
/// the price shown on a /coupons/{brand} page is computed from
/// `effectiveDiscountBps(msg.sender)` for an authenticated user.
contract TieredDiscount {
    struct Tier {
        uint256 threshold;   // minimum token balance for this tier
        uint16 discountBps;  // discount in basis points (100 = 1%)
    }

    IERC8063 public immutable groupToken;
    Tier[] public tiers; // MUST be configured in ascending threshold order

    event TierAdded(uint256 threshold, uint16 discountBps);

    constructor(address token, Tier[] memory initialTiers) {
        require(token != address(0), "Zero token");
        groupToken = IERC8063(token);
        uint256 lastThreshold = 0;
        for (uint256 i = 0; i < initialTiers.length; i++) {
            require(initialTiers[i].threshold > lastThreshold, "Tiers must be ascending");
            require(initialTiers[i].discountBps <= 10_000, "Discount > 100%");
            tiers.push(initialTiers[i]);
            lastThreshold = initialTiers[i].threshold;
            emit TierAdded(initialTiers[i].threshold, initialTiers[i].discountBps);
        }
    }

    /// @notice Return the best discount this account qualifies for, in basis points
    /// @return discountBps Discount in basis points (0 = no discount, 10000 = free)
    function effectiveDiscountBps(address account) public view returns (uint16 discountBps) {
        for (uint256 i = tiers.length; i > 0; i--) {
            if (groupToken.isMember(account, tiers[i - 1].threshold)) {
                return tiers[i - 1].discountBps;
            }
        }
        return 0;
    }

    /// @notice Apply this account's discount to a list price
    /// @return finalPrice listPrice * (1 - effectiveDiscountBps/10000)
    function discountedPrice(address account, uint256 listPrice) external view returns (uint256) {
        uint16 bps = effectiveDiscountBps(account);
        if (bps == 0) return listPrice;
        return listPrice - (listPrice * bps) / 10_000;
    }

    /// @notice Read tier configuration
    function tierCount() external view returns (uint256) {
        return tiers.length;
    }
}
