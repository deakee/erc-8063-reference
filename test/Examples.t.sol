// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC8063.sol";
import "../examples/GroupGate.sol";
import "../examples/TieredDiscount.sol";
import "../examples/CrossGroupBundle.sol";

/// Concrete GroupGate consumer for testing the abstract pattern
contract PremiumFeature is GroupGate {
    constructor(address t, uint256 thresh) GroupGate(t, thresh) {}
    function doPremium() external view onlyMember returns (uint256) { return 42; }
}

contract ExamplesTest is Test {
    ERC8063 internal token;
    ERC8063 internal token2;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xA1);
    address internal bob   = address(0xB2);

    function setUp() public {
        vm.prank(owner);
        token = new ERC8063("Brand A", "BA", 18, 1_000_000 ether);
        vm.prank(owner);
        token2 = new ERC8063("Brand B", "BB", 18, 1_000_000 ether);
    }

    // ── GroupGate ────────────────────────────────────────────────────────

    function test_groupgate_blocks_non_member() public {
        PremiumFeature pf = new PremiumFeature(address(token), 100 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GroupGate.NotAMember.selector, alice, 100 ether));
        pf.doPremium();
    }

    function test_groupgate_admits_member() public {
        PremiumFeature pf = new PremiumFeature(address(token), 100 ether);
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        assertEq(pf.doPremium(), 42);
    }

    // ── TieredDiscount ───────────────────────────────────────────────────

    function _threeTier() internal returns (TieredDiscount) {
        TieredDiscount.Tier[] memory tiers = new TieredDiscount.Tier[](3);
        tiers[0] = TieredDiscount.Tier({ threshold:    100 ether, discountBps:  500 }); //  5%
        tiers[1] = TieredDiscount.Tier({ threshold:  1_000 ether, discountBps: 1000 }); // 10%
        tiers[2] = TieredDiscount.Tier({ threshold: 10_000 ether, discountBps: 2000 }); // 20%
        return new TieredDiscount(address(token), tiers);
    }

    function test_tiered_zero_balance_no_discount() public {
        TieredDiscount d = _threeTier();
        assertEq(d.effectiveDiscountBps(alice), 0);
        assertEq(d.discountedPrice(alice, 100 ether), 100 ether);
    }

    function test_tiered_t1_discount() public {
        TieredDiscount d = _threeTier();
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        assertEq(d.effectiveDiscountBps(alice), 500);
        assertEq(d.discountedPrice(alice, 100 ether), 95 ether);
    }

    function test_tiered_t3_discount() public {
        TieredDiscount d = _threeTier();
        vm.prank(owner);
        token.transfer(alice, 10_000 ether);
        assertEq(d.effectiveDiscountBps(alice), 2000);
        assertEq(d.discountedPrice(alice, 100 ether), 80 ether);
    }

    function test_tiered_picks_best_tier_member_qualifies_for() public {
        TieredDiscount d = _threeTier();
        vm.prank(owner);
        token.transfer(alice, 5_000 ether); // qualifies for T2 (1000+), not T3 (10000)
        assertEq(d.effectiveDiscountBps(alice), 1000);
    }

    function test_tiered_rejects_descending_thresholds() public {
        TieredDiscount.Tier[] memory bad = new TieredDiscount.Tier[](2);
        bad[0] = TieredDiscount.Tier({ threshold: 1000 ether, discountBps: 1000 });
        bad[1] = TieredDiscount.Tier({ threshold:  100 ether, discountBps:  500 });
        vm.expectRevert(bytes("Tiers must be ascending"));
        new TieredDiscount(address(token), bad);
    }

    // ── CrossGroupBundle ─────────────────────────────────────────────────

    function _bundleAB() internal view returns (CrossGroupBundle.GroupRequirement[] memory) {
        CrossGroupBundle.GroupRequirement[] memory reqs = new CrossGroupBundle.GroupRequirement[](2);
        reqs[0] = CrossGroupBundle.GroupRequirement({ group: IERC8063(address(token)),  threshold: 100 ether });
        reqs[1] = CrossGroupBundle.GroupRequirement({ group: IERC8063(address(token2)), threshold: 100 ether });
        return reqs;
    }

    function test_bundle_requires_all_groups() public {
        CrossGroupBundle bundle = new CrossGroupBundle(_bundleAB());
        assertFalse(bundle.isQualified(alice));

        vm.prank(owner);
        token.transfer(alice, 100 ether);
        assertFalse(bundle.isQualified(alice)); // still missing token2

        vm.prank(owner);
        token2.transfer(alice, 100 ether);
        assertTrue(bundle.isQualified(alice));
    }

    function test_bundle_any_or_semantics() public {
        CrossGroupBundle bundle = new CrossGroupBundle(_bundleAB());
        assertFalse(bundle.isQualifiedAny(alice));

        vm.prank(owner);
        token.transfer(alice, 100 ether); // just token A
        assertTrue(bundle.isQualifiedAny(alice));
        assertFalse(bundle.isQualified(alice));
    }
}
